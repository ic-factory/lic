# frozen_string_literal: true

require "lic/cli"

RSpec.describe "lic executable" do
  it "returns non-zero exit status when passed unrecognized options" do
    lic "--invalid_argument"
    expect(exitstatus).to_not be_zero if exitstatus
  end

  it "returns non-zero exit status when passed unrecognized task" do
    lic "unrecognized-task"
    expect(exitstatus).to_not be_zero if exitstatus
  end

  it "looks for a binary and executes it if it's named lic-<task>" do
    File.open(tmp("lic-testtasks"), "w", 0o755) do |f|
      ruby = ENV["LIC_RUBY"] || "/usr/bin/env ruby"
      f.puts "#!#{ruby}\nputs 'Hello, world'\n"
    end

    with_path_added(tmp) do
      lic "testtasks"
    end

    expect(exitstatus).to be_zero if exitstatus
    expect(out).to eq("Hello, world")
  end

  context "with no arguments" do
    it "prints a concise help message", :lic => "2" do
      lic! ""
      expect(last_command.stderr).to be_empty
      expect(last_command.stdout).to include("Lic version #{Lic::VERSION}").
        and include("\n\nLic commands:\n\n").
        and include("\n\n  Primary commands:\n").
        and include("\n\n  Utilities:\n").
        and include("\n\nOptions:\n")
    end
  end

  context "when ENV['LIC_GEMFILE'] is set to an empty string" do
    it "ignores it" do
      gemfile licd_app("Gemfile"), <<-G
        source "file://#{gem_repo1}"
        gem 'rack'
      G

      lic :install, :env => { "LIC_GEMFILE" => "" }

      expect(the_lic).to include_gems "rack 1.0.0"
    end
  end

  context "when ENV['RUBYGEMS_GEMDEPS'] is set" do
    it "displays a warning" do
      gemfile licd_app("Gemfile"), <<-G
        source "file://#{gem_repo1}"
        gem 'rack'
      G

      lic :install, :env => { "RUBYGEMS_GEMDEPS" => "foo" }
      expect(out).to include("RUBYGEMS_GEMDEPS")
      expect(out).to include("conflict with Lic")

      lic :install, :env => { "RUBYGEMS_GEMDEPS" => "" }
      expect(out).not_to include("RUBYGEMS_GEMDEPS")
    end
  end

  context "with --verbose" do
    it "prints the running command" do
      gemfile ""
      lic! "info lic", :verbose => true
      expect(last_command.stdout).to start_with("Running `lic info lic --verbose` with lic #{Lic::VERSION}")
    end

    it "doesn't print defaults" do
      install_gemfile! "", :verbose => true
      expect(last_command.stdout).to start_with("Running `lic install --retry 0 --verbose` with lic #{Lic::VERSION}")
    end

    it "doesn't print defaults" do
      install_gemfile! "", :verbose => true
      expect(last_command.stdout).to start_with("Running `lic install --retry 0 --verbose` with lic #{Lic::VERSION}")
    end
  end

  describe "printing the outdated warning" do
    shared_examples_for "no warning" do
      it "prints no warning" do
        lic "fail"
        expect(last_command.stdboth).to eq("Could not find command \"fail\".")
      end
    end

    let(:lic_version) { "1.1" }
    let(:latest_version) { nil }
    before do
      lic! "config --global disable_version_check false"

      simulate_lic_version(lic_version)
      if latest_version
        info_path = home(".lic/cache/compact_index/rubygems.org.443.29b0360b937aa4d161703e6160654e47/info/lic")
        info_path.parent.mkpath
        info_path.open("w") {|f| f.write "#{latest_version}\n" }
      end
    end

    context "when there is no latest version" do
      include_examples "no warning"
    end

    context "when the latest version is equal to the current version" do
      let(:latest_version) { lic_version }
      include_examples "no warning"
    end

    context "when the latest version is less than the current version" do
      let(:latest_version) { "0.9" }
      include_examples "no warning"
    end

    context "when the latest version is greater than the current version" do
      let(:latest_version) { "222.0" }
      it "prints the version warning" do
        lic "fail"
        expect(last_command.stdout).to start_with(<<-EOS.strip)
The latest lic is #{latest_version}, but you are currently running #{lic_version}.
To install the latest version, run `gem install lic`
        EOS
      end

      context "and disable_version_check is set" do
        before { lic! "config disable_version_check true" }
        include_examples "no warning"
      end

      context "running a parseable command" do
        it "prints no warning" do
          lic! "config --parseable foo"
          expect(last_command.stdboth).to eq ""

          lic "platform --ruby"
          expect(last_command.stdboth).to eq "Could not locate Gemfile"
        end
      end

      context "and is a pre-release" do
        let(:latest_version) { "222.0.0.pre.4" }
        it "prints the version warning" do
          lic "fail"
          expect(last_command.stdout).to start_with(<<-EOS.strip)
The latest lic is #{latest_version}, but you are currently running #{lic_version}.
To install the latest version, run `gem install lic --pre`
          EOS
        end
      end
    end
  end
end

RSpec.describe "lic executable" do
  it "shows the lic version just as the `lic` executable does", :lic => "< 2" do
    lic "--version"
    expect(out).to eq("Lic version #{Lic::VERSION}")
  end

  it "shows the lic version just as the `lic` executable does", :lic => "2" do
    lic "--version"
    expect(out).to eq(Lic::VERSION)
  end
end
