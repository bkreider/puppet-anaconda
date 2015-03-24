require 'spec_helper'
require 'stringio'
require 'fileutils'

provider = Puppet::Type.type(:package).provider(:conda)

describe provider do

  before(:all) do
    # stub out conda executable
  end

  before(:each) do
    @resource = Puppet::Type.type(:package).new(
      :name     => 'env_name::package_name',
      :ensure   => :present,
      :provider => :conda,
    )
    @provider = provider.new(@resource)
  end

  it "should have an install method" do
    @provider.should respond_to(:install)
  end

  it "should have an uninstall method" do
    @provider.should respond_to(:uninstall)
  end

  it "should have an update method" do
    @provider.should respond_to(:update)
  end

  it "should have a latest method" do
    @provider.should respond_to(:latest)
  end

  it "should have an instances class method" do
    provider.should respond_to(:instances)
  end


  describe "provider" do

    it "should have windows conda exe set" do
      provider.expects(:is_windows?).at_least_once.returns true
      provider.get_conda_cmd.should == 'C:\Anaconda\Scripts\conda.exe'
    end

    it "should have linux conda exe set" do
      provider.expects(:is_windows?).at_least_once.returns false
      provider.get_conda_cmd.should == '/opt/anaconda/bin/conda'
    end

    it "should have windows envs path set" do
      provider.expects(:is_windows?).at_least_once.returns true
      provider.get_env_path.should == 'C:\Anaconda\envs'
    end

    it "should have linux envs path set" do
      provider.expects(:is_windows?).at_least_once.returns false
      provider.get_env_path.should == '/opt/anaconda/envs'
    end

    it "should know listing for linux" do
      provider.expects(:is_windows?).at_least_once.returns false
      provider.get_dir_listing_cmd.should == 'ls -1'
    end

    it "should know listing for windows" do
      provider.expects(:is_windows?).at_least_once.returns true
      provider.get_dir_listing_cmd.should == 'dir /b'
    end

  end


  context "parameter :source" do

    it "should default to nil" do
      @resource[:source].should be_nil
    end

    it "should accept http://somelocation/packages" do
      @resource[:source] = 'http://somelocation/packages'
    end

  end


  context "method :instances" do

    it 'should be able to parse package info from conda list output' do
      provider.parse_conda_list_item("bitarray-0.8.1-py27_1\n").should ==
        {:ensure => "0.8.1", :name => "bitarray", :provider => :conda}
    end

    it 'should be able to parse package info from conda list with env output' do
      provider.parse_conda_list_item("bitarray-0.8.1-py27_1\n","an_env").should ==
        {:ensure => "0.8.1", :name => "an_env::bitarray", :provider => :conda}
    end

    it 'should use conda command to enumerate packages' do
      provider.stubs(:is_windows?).returns true
      provider.expects(:execpipe).with('C:\Anaconda\Scripts\conda.exe list -c').yields(StringIO.new(""))
      provider.get_instances_from_conda.should == []
    end

    it 'should use conda command to enumerate environments' do
      provider.stubs(:is_windows?).returns true
      provider.expects(:execpipe).with('C:\Anaconda\Scripts\conda.exe list -c -n my_env').
        yields(StringIO.new(%q[
bitarray-0.8.1-py27_1
blaze-0.6.3-np19py27_0
blz-0.6.2-np19py27_0
                            ]))
        provider.stubs(:parse_conda_list_item).with(responds_with(:strip, ""), 'my_env').
          returns nil
        provider.expects(:parse_conda_list_item).with("bitarray-0.8.1-py27_1\n", 'my_env').
          returns({:ensure => "0.8.1", :name => "my_env::bitarray", :provider => :conda})
        provider.expects(:parse_conda_list_item).with("blaze-0.6.3-np19py27_0\n", 'my_env').
          returns({:ensure => "0.6.3", :name => "my_env::blaze", :provider => :conda})
        provider.expects(:parse_conda_list_item).with("blz-0.6.2-np19py27_0\n", 'my_env').
          returns({:ensure => "0.6.2", :name => "my_env::blz", :provider => :conda})
        the_instances = provider.get_instances_from_conda('my_env')
        the_instances.length.should == 3
        the_instances[0].name.should == "my_env::bitarray"
        the_instances[1].name.should == "my_env::blaze"
        the_instances[2].name.should == "my_env::blz"
    end

    it 'should enumerate environments' do
      provider.stubs(:is_windows?).returns true
      provider.expects(:execpipe).with('dir /b C:\Anaconda\envs').yields(StringIO.new("env1\nenv2\n"))
      provider.expects(:get_instances_from_conda).with().returns(["fake_package1","fake_package2"])
      provider.expects(:get_instances_from_conda).with("env1").returns(["env1::fake_package1","env1::fake_package2"])
      provider.expects(:get_instances_from_conda).with("env2").returns(["env2::fake_package1","env2::fake_package2"])
      provider.instances.should == ["fake_package1","fake_package2","env1::fake_package1",
                                    "env1::fake_package2","env2::fake_package1","env2::fake_package2"]
    end

  end


  describe "query" do

    it "should return a hash when package is present" do
      fake_resource = Object.new
      fake_resource.class.module_eval { attr_accessor :name}
      fake_resource.class.module_eval { attr_accessor :properties}
      fake_resource.name = 'env_name::package_name'
      fake_resource.properties = 'the resourceproperties'

      provider.expects(:instances).returns [fake_resource]
      @provider.query.should == fake_resource.properties
    end

    it "should return a hash when package is in wrong case" do
      fake_resource = Object.new
      fake_resource.class.module_eval { attr_accessor :name}
      fake_resource.class.module_eval { attr_accessor :properties}
      fake_resource.name = 'env_Name::Package_Name'
      fake_resource.properties = 'the resourceproperties'

      provider.expects(:instances).returns [fake_resource]
      @provider.query.should == fake_resource.properties
    end

    it "should return nil when no packages" do
      provider.expects(:instances).returns []
      @provider.query.should be_nil
    end

    it "should return nil when no matching packages" do
      fake_resource = Object.new
      fake_resource.class.module_eval { attr_accessor :name}
      fake_resource.class.module_eval { attr_accessor :properties}
      fake_resource.name = 'wrong_env::package_name'
      fake_resource.properties = 'the resourceproperties'

      provider.expects(:instances).returns [fake_resource]
      @provider.query.should be_nil
    end

  end


  describe "when installing" do


  end


  describe "when uninstalling" do

  end

end
