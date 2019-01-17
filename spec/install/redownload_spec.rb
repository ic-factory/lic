# frozen_string_literal: true

RSpec.describe "lic install" do
  before :each do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G
  end

  shared_examples_for "an option to force redownloading gems" do
    it "re-installs installed gems" do
      rack_lib = default_lic_path("gems/rack-1.0.0/lib/rack.rb")

      lic! :install
      rack_lib.open("w") {|f| f.write("blah blah blah") }
      lic! :install, flag => true

      expect(out).to include "Installing rack 1.0.0"
      expect(rack_lib.open(&:read)).to eq("RACK = '1.0.0'\n")
      expect(the_lic).to include_gems "rack 1.0.0"
    end

    it "works on first lic install" do
      lic! :install, flag => true

      expect(out).to include "Installing rack 1.0.0"
      expect(the_lic).to include_gems "rack 1.0.0"
    end

    context "with a git gem" do
      let!(:ref) { build_git("foo", "1.0").ref_for("HEAD", 11) }

      before do
        gemfile <<-G
          gem "foo", :git => "#{lib_path("foo-1.0")}"
        G
      end

      it "re-installs installed gems" do
        foo_lib = default_lic_path("lic/gems/foo-1.0-#{ref}/lib/foo.rb")

        lic! :install
        foo_lib.open("w") {|f| f.write("blah blah blah") }
        lic! :install, flag => true

        expect(foo_lib.open(&:read)).to eq("FOO = '1.0'\n")
        expect(the_lic).to include_gems "foo 1.0"
      end

      it "works on first lic install" do
        lic! :install, flag => true

        expect(the_lic).to include_gems "foo 1.0"
      end
    end
  end

  describe "with --force" do
    it_behaves_like "an option to force redownloading gems" do
      let(:flag) { "force" }
    end

    it "shows a deprecation when single flag passed", :lic => 2 do
      lic! "install --force"
      expect(out).to include "[DEPRECATED FOR 2.0] The `--force` option has been renamed to `--redownload`"
    end

    it "shows a deprecation when multiple flags passed", :lic => 2 do
      lic! "install --no-color --force"
      expect(out).to include "[DEPRECATED FOR 2.0] The `--force` option has been renamed to `--redownload`"
    end

    it "does not show a deprecation when single flag passed", :lic => "< 2" do
      lic! "install --force"
      expect(out).not_to include "[DEPRECATED FOR 2.0] The `--force` option has been renamed to `--redownload`"
    end

    it "does not show a deprecation when multiple flags passed", :lic => "< 2" do
      lic! "install --no-color --force"
      expect(out).not_to include "[DEPRECATED FOR 2.0] The `--force` option has been renamed to `--redownload`"
    end
  end

  describe "with --redownload" do
    it_behaves_like "an option to force redownloading gems" do
      let(:flag) { "redownload" }
    end

    it "does not show a deprecation when single flag passed" do
      lic! "install --redownload"
      expect(out).not_to include "[DEPRECATED FOR 2.0] The `--force` option has been renamed to `--redownload`"
    end

    it "does not show a deprecation when single multiple flags passed" do
      lic! "install --no-color --redownload"
      expect(out).not_to include "[DEPRECATED FOR 2.0] The `--force` option has been renamed to `--redownload`"
    end
  end
end
