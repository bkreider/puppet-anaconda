require 'puppet/provider/package'
require 'xmlrpc/client'

Puppet::Type.type(:package).provide :conda,
    :parent => ::Puppet::Provider::Package do

    desc "Conda packages via `conda`."

    has_feature :installable, :uninstallable, :upgradeable, :versionable

    # ##
    # OS dependant properties
    # ##

    def self.is_windows?
        ENV['OS'] == 'Windows_NT'
    end

    def self.get_install_path
        return "C:\\Anaconda" if is_windows?
        "/opt/anaconda"
    end

    def self.get_conda_cmd
        return "#{get_install_path}\\Scripts\\conda.exe" if is_windows?
        "#{get_install_path}/bin/conda"
    end

    def self.get_env_path
        return "#{get_install_path}\\envs" if is_windows?
        "#{get_install_path}/envs"
    end

    def self.get_dir_listing_cmd
        return 'dir /b' if is_windows?
        'ls -1'
    end

    commands :conda => get_conda_cmd

    # ##
    # helper class methods
    # ##

    def self.parse_conda_list_item(line, env="")
        # Need a right split, because package names can contain "-"
        package, junk, conda_build = line.rpartition("-")
        if not package
            return nil
        end

        package_name, junk, version = package.rpartition("-")
        if env != ""
            package_name = "#{env}::#{package_name}"
        end

        {:ensure => version, :name => package_name, :provider => name}
    end

    def self.get_instances_from_conda(env="")
        packages = []
        cmd_line = "#{get_conda_cmd} list -c"
        if env != ""
            cmd_line += " -n #{env}"
        end
        # This commandlines used to have '|| /bin/true' it may be necesary to introduce a catch block instead.
        execpipe cmd_line do |process|
            process.collect do |line|
                next unless options = parse_conda_list_item(line, env)
                packages << new(options)
            end
        end
        packages
    end

    def self.get_envs
        envs = []
        execpipe "#{get_dir_listing_cmd} #{get_env_path}" do |env_names|
            env_names.collect do |temp_env|
                envs << temp_env.strip
            end
        end
        envs
    end

    # ##
    # Package Provider implementation
    # ##

    public
    def self.instances
        packages = get_instances_from_conda()

        get_envs.collect do |env|
            env_packages = get_instances_from_conda(env)
            packages.push(*env_packages)
        end

        packages
    end

    public
    def install
        args = %w{install --yes --quiet}

        env, package = parse_env(@resource[:name])

        if not env.nil?
            args << "-n"
            args << "#{env}"
        end

        if @resource[:source].to_s != ''
            args << "--channel"
            args << @resource[:source].to_s
            args << "--override-channels"
        end

        case @resource[:ensure]
        when String
            args << "#{package}=#{@resource[:ensure]}"
        when :latest
            args << package
        else
            args << package
        end

        if not env.nil?
            available_envs = self.class.get_envs
            if not available_envs.include? env
                raise Puppet::Error.new("Package #{resource[:name]} version "\
                                        "#{@resource[:ensure]} is in an error "\
                                        "state: env #{env} does not exist")
            end
        end
        Puppet.debug "calling >>conda #{args.join(' ')}"
        conda *args
    end

    public
    def uninstall
        args = %w{remove --yes}
        env, package = parse_env(@resource[:name])

        if env != nil
            args << "-n"
            args << "#{env}"
        end

        args << package
        conda *args
    end

    # todo - make it work with other python versions
    def latest
        args  = %w{search --canonical}

        env, package = parse_env(@resource[:name])
        if env != nil
            args << "-n"
            args << "#{env}"
        end

        if @resource[:source].to_s != ''
            args << "--channel"
            args << @resource[:source].to_s
            args << "--override-channels"
        end

        args << "^#{package}$"

        versions = []
        command = "#{self.class.get_conda_cmd} #{args.join(' ')}"
        execpipe command do |process|
            process.collect do |line|
                next unless options= parse_search(line, "py27")
                versions << options
            end
        end

        return nil if versions.empty?
        # return highest version
        versions.map {|v| Gem::Version.new v}.max.to_s
    end

    public
    def update
        install
    end

    public
    def query
        self.class.instances.each do |provider_conda|
            if @resource[:name].downcase == provider_conda.name.downcase
                return provider_conda.properties
            end
        end
        return nil
    end


    # ##
    # Private instance methods
    # ##

    private
    def parse_env(name)
        env, delim, package = name.partition('::')
        if delim == ""
            # If env delim not found, first entry is the package name
            package = env
            env = nil
        elsif env != ""
            # found env and package
        else
            # Overspecified which is valid: "", "::", "packagename"
            env = nil
        end
        [env, package]
    end

    private
    def parse_search(line, py_ver_check)

        # Need a right split, because package names can contain "-"
        package, junk, conda_build = line.rpartition("-")
        if not package
            return nil
        end
        package_name, junk, version = package.rpartition("-")

        # The conda_build string needs to match the Python version: ie: py27
        if conda_build.index(py_ver_check).nil?
            return nil
        end
        version
    end
end




