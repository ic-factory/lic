# frozen_string_literal: true

RSpec.describe "Running bin/* commands" do
  before :each do
    install_gemfile! <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G
  end

  it "runs the licd command when in the lic" do
    lic! "binstubs rack"

    build_gem "rack", "2.0", :to_system => true do |s|
      s.executables = "rackup"
    end

    gembin "rackup"
    expect(out).to eq("1.0.0")
  end

  it "allows the location of the gem stubs to be specified" do
    lic! "binstubs rack", :path => "gbin"

    expect(licd_app("bin")).not_to exist
    expect(licd_app("gbin/rackup")).to exist

    gembin licd_app("gbin/rackup")
    expect(out).to eq("1.0.0")
  end

  it "allows absolute paths as a specification of where to install bin stubs" do
    lic! "binstubs rack", :path => tmp("bin")

    gembin tmp("bin/rackup")
    expect(out).to eq("1.0.0")
  end

  it "uses the default ruby install name when shebang is not specified" do
    lic! "binstubs rack"
    expect(File.open("bin/rackup").gets).to eq("#!/usr/bin/env #{RbConfig::CONFIG["ruby_install_name"]}\n")
  end

  it "allows the name of the shebang executable to be specified" do
    lic! "binstubs rack", :shebang => "ruby-foo"
    expect(File.open("bin/rackup").gets).to eq("#!/usr/bin/env ruby-foo\n")
  end

  it "runs the licd command when out of the lic" do
    lic! "binstubs rack"

    build_gem "rack", "2.0", :to_system => true do |s|
      s.executables = "rackup"
    end

    Dir.chdir(tmp) do
      gembin "rackup"
      expect(out).to eq("1.0.0")
    end
  end

  it "works with gems in path" do
    build_lib "rack", :path => lib_path("rack") do |s|
      s.executables = "rackup"
    end

    gemfile <<-G
      gem "rack", :path => "#{lib_path("rack")}"
    G

    lic! "binstubs rack"

    build_gem "rack", "2.0", :to_system => true do |s|
      s.executables = "rackup"
    end

    gembin "rackup"
    expect(out).to eq("1.0")
  end

  it "creates a lic binstub" do
    build_gem "lic", Lic::VERSION, :to_system => true do |s|
      s.executables = "lic"
    end

    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "lic"
    G

    lic! "binstubs lic"

    expect(licd_app("bin/lic")).to exist
  end

  it "does not generate bin stubs if the option was not specified" do
    lic! "install"

    expect(licd_app("bin/rackup")).not_to exist
  end

  it "allows you to stop installing binstubs", :lic => "< 2" do
    lic! "install --binstubs bin/"
    licd_app("bin/rackup").rmtree
    lic! "install --binstubs \"\""

    expect(licd_app("bin/rackup")).not_to exist

    lic! "config bin"
    expect(out).to include("You have not configured a value for `bin`")
  end

  it "remembers that the option was specified", :lic => "< 2" do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "activesupport"
    G

    lic! :install, forgotten_command_line_options([:binstubs, :bin] => "bin")

    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "activesupport"
      gem "rack"
    G

    lic "install"

    expect(licd_app("bin/rackup")).to exist
  end

  it "rewrites bins on --binstubs (to maintain backwards compatibility)", :lic => "< 2" do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G

    lic! :install, forgotten_command_line_options([:binstubs, :bin] => "bin")

    File.open(licd_app("bin/rackup"), "wb") do |file|
      file.print "OMG"
    end

    lic "install"

    expect(licd_app("bin/rackup").read).to_not eq("OMG")
  end

  it "rewrites bins on binstubs (to maintain backwards compatibility)" do
    install_gemfile! <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G

    create_file("bin/rackup", "OMG")

    lic! "binstubs rack"

    expect(licd_app("bin/rackup").read).to_not eq("OMG")
  end

  it "use LIC_GEMFILE gemfile for binstub" do
    # context with bin/bunlder w/ default Gemfile
    lic! "binstubs lic"

    # generate other Gemfile with executable gem
    build_repo2 do
      build_gem("bindir") {|s| s.executables = "foo" }
    end

    create_file("OtherGemfile", <<-G)
      source "file://#{gem_repo2}"
      gem 'bindir'
    G

    # generate binstub for executable from non default Gemfile (other then bin/lic version)
    ENV["LIC_GEMFILE"] = "OtherGemfile"
    lic "install"
    lic! "binstubs bindir"

    # remove user settings
    ENV["LIC_GEMFILE"] = nil

    # run binstub for non default Gemfile
    gembin "foo"

    expect(exitstatus).to eq(0) if exitstatus
    expect(out).to eq("1.0")
  end
end
