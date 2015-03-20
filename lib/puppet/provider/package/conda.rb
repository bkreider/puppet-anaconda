require 'puppet/provider/package'
require 'xmlrpc/client'

Puppet::Type.type(:package).provide :conda,
  :parent => ::Puppet::Provider::Package do

  desc "Conda packages via `conda`."

  has_feature :installable, :uninstallable, :upgradeable, :versionable

  @install_path = "/opt/anaconda"
  @conda_cmd    = "#{@install_path}/bin/conda"
  @env_path     = "#{@install_path}/envs"
  commands :conda => @conda_cmd

  @env_delim = "::"

  def self.parse(line, env="")
    # Need a right split, because package names can contain "-"
    package, junk, conda_build = line.rpartition("-")

    if not package
      return nil
    end

    package_name, junk, version = package.rpartition("-")

    # Add env prefix
    if env != ""
      package_name = "#{env}::#{package_name}"
    end
    #puts "#{package_name} #{version}"

    # formatted as parameters for provider instantiation
    {:ensure => version, :name => package_name, :provider => name}
  end

  def self.instances

    packages = []

    # bug where conda list gives an error return value
    execpipe "#{@conda_cmd} list -c || /bin/true" do |process|
      process.collect do |line|
        next unless options = parse(line)
        #puts "Storing options: #{options}"
        packages << new(options)
      end
    end

    # Check for envs
    execpipe "ls #{@env_path}" do |env_names|
      env_names.collect do |temp_env|
        env = temp_env.strip
        #puts "Working on env:#{env}<<"

        # bug where conda list gives an error return value
        execpipe "#{@conda_cmd} list -c -n #{env} || /bin/true" do |process|
          process.collect do |line|
            next unless options = parse(line, env)
            #puts "Storing options: #{options}"
            packages << new(options)
          end
        end
      end
    end

    #puts packages.inspect
    packages
  end

  def install
    args = %w{install --yes --quiet}

    env, package = parse_env(@resource[:name])

    if not env.nil?
      args << "-n" 
      args << "#{env}"
    else
      #puts "env:#{env} / package:#{package}"
    end

    case @resource[:ensure]
    when String
      args << "#{package}==#{@resource[:ensure]}"
    when :latest
      args << package
    else
      args << package
    end

    if not env.nil?
      # Verify ENV exists
      found = false
      execpipe "ls #{@env_path}" do |env_names|
        env_names.collect do |temp_env|
          fs_env = temp_env.strip
          if fs_env == env
            #puts "Found env"
            found = true
            break
          end
        end
      end

      # Don't autocreate envs that don't exist
      #if not found
      #    create_args = %w{create --yes --quiet -n}
      #    create_args << env
      #    create_args << "python"
      #    puts "Creating env #{create_args.join(" ")}"
      #    conda *create_args
      #end
      if not found
        raise Puppet::Error.new("Package #{resource[:name]} version "\
                                "#{@resource[:ensure]} is in an error "\
                                "state: env #{env} does not exist")
      end

    end

    Puppet.debug "calling >>conda #{args.join(' ')}"
    conda *args
  end

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
    args  = %w{search -c}

    # Is it in an env?
    env, package = parse_env(@resource[:name])
    if env != nil
      args << "-n" 
      args << "#{env}"
    end

    args << "^#{package}$"

    versions = []
    # todo: support other python versions
    command = "#{@conda_cmd} #{args.join(' ')} || /bin/true"
    #puts command
    execpipe command do |process|
      process.collect do |line|
        next unless options= parse_search(line)
        #puts "Storing options: #{options}"
        versions << options
      end
    end

    #puts versions.inspect
    # return highest version
    versions.map {|v| Gem::Version.new v}.max.to_s
  end

  def update
    install
  end

  def query
    self.class.instances.each do |provider_conda|
      if @resource[:name] == provider_conda.name
        return provider_conda.properties
      end
    end
    return nil
  end

  private
  def parse_env(name)
    # Returns (env, package)
    # env = nil if it is the root env

    # If env delim not found, first entry is the package name
    env, delim, package = name.partition(@env_delim)
    if delim == ""
      # root package
      package = env
      env = nil
    elsif env != ""
      # found env and package
      #puts "env=#{env}, package=#{package}"
    else
      # Overspecified which is valid:
      # "", "::", "packagename"
      #puts "overspecified #{env}, #{delim}, #{package}"
      env = nil
    end
    [env, package]
  end

  # Parse searching for latest valid package
  private
  def parse_search(line, python="py27")

    # Need a right split, because package names can contain "-"
    package, junk, conda_build = line.rpartition("-")

    if not package
      return nil
    end

    package_name, junk, version = package.rpartition("-")

    # The conda_build string needs to match the Python version: ie: py27
    if not conda_build.index(python).nil?
      return version
    else
      return nil
    end

  end
end




