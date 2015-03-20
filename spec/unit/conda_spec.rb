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


  context "parameter :source" do

    it "should default to nil" do
      @resource[:source].should be_nil
    end

    it "should accept c:\\packages" do
      @resource[:source] = 'c:\packages'
    end

    it "should accept http://somelocation/packages" do
      @resource[:source] = 'http://somelocation/packages'
    end

    it "should get mapped to a -c switch" do
    end

  end


  context "method :instances" do

  end


  describe "when installing" do


  end


  describe "when uninstalling" do

  end


  describe "query" do

    it "should return a hash when nuget and the package are present" do
      provider.expects(:is_directory).returns true
      provider.expects(:getversion).returns "1.2.5"

      @provider.query.should == {
        :ensure   => "1.2.5",
        :name     => 'c:\temp\nuget\testpackage',
        :provider => :nuget,
      }

    end

    it "should return nil when the package is missing" do
      provider.expects(:is_directory).returns true
      provider.expects(:getversion).returns nil
      @provider.query.should be_nil
    end

    it "should return nil when the env is missing" do
      provider.expects(:is_directory).returns false
      @provider.query.should be_nil
    end

  end


  describe "when fetching a package list" do

    it "should invoke provider getversioncmd" do
      provider.expects(:getversioncmd).returns "fake_cmd"
      provider.expects(:execpipe).with("fake_cmd")
      @provider.latest
    end

    it "should query nuget" do
      provider.expects(:execpipe).with() { |args| args[0] =~ /nuget.exe/ && args[1] == 'list' }
      @provider.latest
    end

    it "should return available package version" do
      provider.expects(:execpipe).yields(StringIO.new(%Q(testpackage 1.23)))
      @provider.latest.should == '1.23'
    end

    it "should return nil on error" do
      provider.expects(:execpipe).raises(Puppet::ExecutionFailure.new("ERROR!"))
      @provider.latest.should be_nil
    end

    it "should return nil on none found" do
      provider.expects(:execpipe).yields(StringIO.new())
      @provider.latest.should be_nil
    end

    it "should return nil on wrong found" do
      provider.expects(:execpipe).yields(StringIO.new(%Q(testpackage2 1.23\n)))
      @provider.latest.should be_nil
    end

    it "shouldn't blow up if no version found" do
      provider.expects(:execpipe).yields(StringIO.new(%Q(testpackage2 \n)))
      @provider.latest.should be_nil
    end

    it "should use prerelease argument" do
      @resource[:flavor] = 'prerelease'
      provider.expects(:execpipe).with() { |arg|
        arg[0] =~ /nuget.exe/ &&
          arg[1] == 'list' &&
          arg[2] == 'testpackage' &&
          arg[3] == '-prerelease' &&
          arg[4] == '| findstr /L ' &&
          arg[5] == 'testpackage'
      }
      @provider.latest
    end

  end

end
