require 'puppet/provider/package'
require 'xmlrpc/client'

Puppet::Type.type(:package).provide :conda,
  :parent => ::Puppet::Provider::Package do

  desc "Conda packages via `conda`."

  has_feature :installable, :uninstallable, :upgradeable, :versionable

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

  @env_delim = "::"

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

  def self.instances
    packages = get_instances_from_conda()

    execpipe "#{get_dir_listing_cmd} #{get_env_path}" do |env_names|
      env_names.collect do |temp_env|
        env = temp_env.strip
        env_packages = get_instances_from_conda(env)
        packages.push(*env_packages)
      end
    end

    packages
  end

  def query
    self.class.instances.each do |provider_conda|
      if @resource[:name].downcase == provider_conda.name.downcase
        return provider_conda.properties
      end
    end
    return nil
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
      found = false
      execpipe "ls #{self.class.get_env_path}" do |env_names|
        env_names.collect do |temp_env|
          fs_env = temp_env.strip
          if fs_env == env
            found = true
            break
          end
        end
      end

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
    command = "#{self.class.get_conda_cmd} #{args.join(' ')} || /bin/true"
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




