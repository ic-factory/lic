# frozen_string_literal: true

require "find"
require "stringio"
require "lic/cli"
require "lic/cli/doctor"

RSpec.describe "lic doctor" do
  before(:each) do
    install_gemfile! <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G

    @stdout = StringIO.new

    [:error, :warn].each do |method|
      allow(Lic.ui).to receive(method).and_wrap_original do |m, message|
        m.call message
        @stdout.puts message
      end
    end
  end

  context "when all files in home are readable/writable" do
    before(:each) do
      stat = double("stat")
      unwritable_file = double("file")
      allow(Find).to receive(:find).with(Lic.home.to_s) { [unwritable_file] }
      allow(File).to receive(:stat).with(unwritable_file) { stat }
      allow(stat).to receive(:uid) { Process.uid }
      allow(File).to receive(:writable?).with(unwritable_file) { true }
      allow(File).to receive(:readable?).with(unwritable_file) { true }
    end

    it "exits with no message if the installed gem has no C extensions" do
      expect { Lic::CLI::Doctor.new({}).run }.not_to raise_error
      expect(@stdout.string).to be_empty
    end

    it "exits with no message if the installed gem's C extension dylib breakage is fine" do
      doctor = Lic::CLI::Doctor.new({})
      expect(doctor).to receive(:lics_for_gem).exactly(2).times.and_return ["/path/to/rack/rack.lic"]
      expect(doctor).to receive(:dylibs).exactly(2).times.and_return ["/usr/lib/libSystem.dylib"]
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with("/usr/lib/libSystem.dylib").and_return(true)
      expect { doctor.run }.not_to(raise_error, @stdout.string)
      expect(@stdout.string).to be_empty
    end

    it "exits with a message if one of the linked libraries is missing" do
      doctor = Lic::CLI::Doctor.new({})
      expect(doctor).to receive(:lics_for_gem).exactly(2).times.and_return ["/path/to/rack/rack.lic"]
      expect(doctor).to receive(:dylibs).exactly(2).times.and_return ["/usr/local/opt/icu4c/lib/libicui18n.57.1.dylib"]
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with("/usr/local/opt/icu4c/lib/libicui18n.57.1.dylib").and_return(false)
      expect { doctor.run }.to raise_error(Lic::ProductionError, strip_whitespace(<<-E).strip), @stdout.string
        The following gems are missing OS dependencies:
         * lic: /usr/local/opt/icu4c/lib/libicui18n.57.1.dylib
         * rack: /usr/local/opt/icu4c/lib/libicui18n.57.1.dylib
      E
    end
  end

  context "when home contains files that are not readable/writable" do
    before(:each) do
      @stat = double("stat")
      @unwritable_file = double("file")
      allow(Find).to receive(:find).with(Lic.home.to_s) { [@unwritable_file] }
      allow(File).to receive(:stat).with(@unwritable_file) { @stat }
    end

    it "exits with an error if home contains files that are not readable/writable" do
      allow(@stat).to receive(:uid) { Process.uid }
      allow(File).to receive(:writable?).with(@unwritable_file) { false }
      allow(File).to receive(:readable?).with(@unwritable_file) { false }
      expect { Lic::CLI::Doctor.new({}).run }.not_to raise_error
      expect(@stdout.string).to include(
        "Files exist in the Lic home that are not readable/writable by the current user. These files are:\n - #{@unwritable_file}"
      )
      expect(@stdout.string).not_to include("No issues")
    end

    context "when home contains files that are not owned by the current process" do
      before(:each) do
        allow(@stat).to receive(:uid) { 0o0000 }
      end

      it "exits with an error if home contains files that are not readable/writable and are not owned by the current user" do
        allow(File).to receive(:writable?).with(@unwritable_file) { false }
        allow(File).to receive(:readable?).with(@unwritable_file) { false }
        expect { Lic::CLI::Doctor.new({}).run }.not_to raise_error
        expect(@stdout.string).to include(
          "Files exist in the Lic home that are owned by another user, and are not readable/writable. These files are:\n - #{@unwritable_file}"
        )
        expect(@stdout.string).not_to include("No issues")
      end

      it "exits with a warning if home contains files that are read/write but not owned by current user" do
        allow(File).to receive(:writable?).with(@unwritable_file) { true }
        allow(File).to receive(:readable?).with(@unwritable_file) { true }
        expect { Lic::CLI::Doctor.new({}).run }.not_to raise_error
        expect(@stdout.string).to include(
          "Files exist in the Lic home that are owned by another user, but are still readable/writable. These files are:\n - #{@unwritable_file}"
        )
        expect(@stdout.string).not_to include("No issues")
      end
    end
  end
end
