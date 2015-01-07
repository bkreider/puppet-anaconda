#Copyright 2013 Continuum Analytics:
#
# Most of this file is duplicated from the pip provider.  it's been
# Modified to interact with Conda and multiple environments.
# 
#Copyright 2011 Richard Crowley. All rights reserved.
#
#Redistribution and use in source and binary forms, with or without
#modification, are permitted provided that the following conditions are
#met:
#
#    1. Redistributions of source code must retain the above copyright
#        notice, this list of conditions and the following disclaimer.
#
#    2. Redistributions in binary form must reproduce the above
#        copyright notice, this list of conditions and the following
#        disclaimer in the documentation and/or other materials provided
#        with the distribution.
#
#THIS SOFTWARE IS PROVIDED BY RICHARD CROWLEY ``AS IS'' AND ANY EXPRESS
#OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#DISCLAIMED. IN NO EVENT SHALL RICHARD CROWLEY OR CONTRIBUTORS BE LIABLE
#FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
#CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
#SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
#INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
#CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
#ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
#THE POSSIBILITY OF SUCH DAMAGE.
#
#The views and conclusions contained in the software and documentation
#are those of the authors and should not be interpreted as representing
#official policies, either expressed or implied, of Richard Crowley.

require 'puppet/provider/package'
require 'xmlrpc/client'

Puppet::Type.type(:package).provide :conda_pip,
  :parent => ::Puppet::Provider::Package do

  desc "Python packages with env support via `pip`."

  has_feature :installable, :uninstallable, :upgradeable, :versionable
  
  @install_path = "/opt/anaconda"
  @pip_cmd      = "#{@install_path}/bin/pip"
  @conda_cmd    = "#{@install_path}/bin/conda"
  @env_path     = "#{@install_path}/envs"
  commands :pip  => @pip_cmd
  
  @env_delim = "::"

  # Parse lines of output from `pip freeze`, which are structured as
  # _package_==_version_.
  def self.parse(line, env="")
    if line.chomp =~ /^([^=]+)==([^=]+)$/
      
      package_name = $1
      if env != ""
        package_name = "#{env}::#{package_name}"
      end
      
      {:ensure => $2, :name => package_name, :provider => name}
    else
      nil
    end
  end

  # Return an array of structured information about every installed package
  # that's managed by `pip` or an empty array if `pip` is not available.
  # We need to subtract the conda managed packages from the total list of packages
  def self.instances
    packages = []
    
    # Hash lookup for conda managed packages
    conda_packages = Hash.new
    self.conda_instances.each do |record|
      conda_packages[record[:name].downcase] = 1
      #puts "storing #{record[:name].downcase}"
    end
    
    execpipe "#{@pip_cmd} freeze" do |process|
      process.collect do |line|
        next unless options = parse(line)
        
        # Does conda manage it?
        if !conda_packages.key?(options[:name].downcase)
          #puts "PIP>> #{options[:name]}"
          packages << new(options)
        else
          #puts "conda manages #{options[:name]}"
        end
      end
    end
    
    # Check for envs
    execpipe "ls #{@env_path}" do |env_names|
      env_names.collect do |temp_env|
        env = temp_env.strip
        execpipe "#{@env_path}/#{env}/bin/pip freeze" do |process|
          process.collect do |line|
            next unless options = parse(line, env)
            
            # Does conda manage it?
            if !conda_packages.key?(options[:name].downcase)
              packages << new(options)
            else
              #puts "conda manages #{options[:name]}"
            end
          end
        end
      end
    end
    
    #puts packages.inspect
    packages
  end

  def self.cmd
    case Facter.value(:osfamily)
      when "RedHat"
        "pip-python"
      else
        "pip"
    end
  end

  # Return structured information about a particular package or `nil` if
  # it is not installed or `pip` itself is not available.
  def query
    self.class.instances.each do |provider_pip|
      if @resource[:name].downcase == provider_pip.name.downcase
        return provider_pip.properties
      end
    end
    return nil
  end

  # Ask the PyPI API for the latest version number.  There is no local
  # cache of PyPI's package list so this operation will always have to
  # ask the web service.
  def latest
    # Is it in an env?
    env, package = parse_env(@resource[:name])
    
    client = XMLRPC::Client.new2("http://pypi.python.org/pypi")
    client.http_header_extra = {"Content-Type" => "text/xml"}
    client.timeout = 10
    result = client.call("package_releases", package)
    result.first
  rescue Timeout::Error => detail
    raise Puppet::Error, "Timeout while contacting pypi.python.org: #{detail}";
  end

  # Install a package.  The ensure parameter may specify installed,
  # latest, a version number, or, in conjunction with the source
  # parameter, an SCM revision.  In that case, the source parameter
  # gives the fully-qualified URL to the repository.
  def install
    args = %w{install -q}
    
    env, package = parse_env(@resource[:name])
        
    
    if @resource[:source]
      if String === @resource[:ensure]
        args << "#{@resource[:source]}@#{@resource[:ensure]}#egg=#{
          package}"
      else
        args << "#{@resource[:source]}#egg=#{package}"
      end
    else
      case @resource[:ensure]
      when String
        args << "#{package}==#{@resource[:ensure]}"
      when :latest
        args << "--upgrade" << package
      else
        args << package
      end
    end
    
    # Envs use their own pip binary
    if not env.nil?
      
        # Does env exist?
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
        if not found
          raise Puppet::Error.new("Package #{resource[:name]} version "\
                                  "#{@resource[:ensure]} is in an error "\
                                  "state: env #{env} does not exist")
        end
        
        #puts "changing pip to use env"
        env_pip = "#{@env_path}/#{env}/bin/pip"
        #self.class.commands :pip => env_pip  <=== this doesn't seem to work
        Puppet.debug "Calling pip with env: #{env_pip} #{args.join(' ')}"
        self.execute("#{env_pip} #{args.join(' ')}")
    else
        #puts "env:#{env} / package:#{package}"
        Puppet.debug "Calling pip:  #{self.command(:pip)}"
        pip *args
    end
    #pip *args
  end

  # Uninstall a package.  Uninstall won't work reliably on Debian/Ubuntu
  # unless this issue gets fixed.
  # <http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=562544>
  def uninstall
    args = ["uninstall", "-y", "-q"]
    
    env, package = parse_env(@resource[:name])
    args << package
    
    # Envs use their own pip binary
    if not env.nil?
        #puts "changing pip to use env"
        env_pip = "#{@env_path}/#{env}/bin/pip"
        #self.class.commands :pip => env_pip  <=== this doesn't seem to work
        Puppet.debug "Calling pip with env: #{env_pip} #{args.join(' ')}"
        self.execute("#{env_pip} #{args.join(' ')}")
    else
        #Puppet.debug "env:#{env} / package:#{package}"
        Puppet.debug "Calling pip:  #{self.command(:pip)}"
        pip *args
    end
  end

  def update
    install
  end

  # Execute a `pip` command.  If Puppet doesn't yet know how to do so,
  # try to teach it and if even that fails, raise the error.
  private
  def lazy_pip(*args)
    pip *args
  rescue NoMethodError => e
    if pathname = which(self.class.cmd)
      self.class.commands :pip => pathname
      pip *args
    else
      raise e, 'Could not locate the pip command.'
    end
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
  
  
  # This is needed because pip freeze shows all of the conda packages as well
  # We need to subtract the conda managed packages from pip freeze
  private
  def self.conda_parse(line, env="")
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

  # This is needed because pip freeze shows all of the conda packages as well
  # We need to subtract the conda managed packages from pip freeze
  private
  def self.conda_instances
    packages = []
    execpipe "#{@conda_cmd} list -c || /bin/true" do |process|
      process.collect do |line|
        next unless options = conda_parse(line)
        packages << options
        end
    end
    
    # Check for envs
    execpipe "ls #{@env_path}" do |env_names|
      env_names.collect do |temp_env|
        env = temp_env.strip
        execpipe "#{@conda_cmd} list -c -n #{env} || /bin/true" do |process|
          process.collect do |line|
            next unless options = conda_parse(line, env)
            packages << options
          end
        end
      end
    end
    
    #puts packages.inspect
    packages
    end
end

