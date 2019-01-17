# frozen_string_literal: true

RSpec.describe "post lic message" do
  before :each do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
      gem "activesupport", "2.3.5", :group => [:emo, :test]
      group :test do
        gem "rspec"
      end
      gem "rack-obama", :group => :obama
    G
  end

  let(:lic_path)                { "./.lic" }
  let(:lic_show_system_message) { "Use `lic info [gemname]` to see where a licd gem is installed." }
  let(:lic_show_path_message)   { "Bundled gems are installed into `#{lic_path}`" }
  let(:lic_complete_message)    { "Bundle complete!" }
  let(:lic_updated_message)     { "Bundle updated!" }
  let(:installed_gems_stats)       { "4 Gemfile dependencies, 5 gems now installed." }
  let(:lic_show_message)        { Lic::VERSION.split(".").first.to_i < 2 ? lic_show_system_message : lic_show_path_message }

  describe "for fresh lic install" do
    it "without any options" do
      lic :install
      expect(out).to include(lic_show_message)
      expect(out).not_to include("Gems in the group")
      expect(out).to include(lic_complete_message)
      expect(out).to include(installed_gems_stats)
    end

    it "with --without one group" do
      lic! :install, forgotten_command_line_options(:without => "emo")
      expect(out).to include(lic_show_message)
      expect(out).to include("Gems in the group emo were not installed")
      expect(out).to include(lic_complete_message)
      expect(out).to include(installed_gems_stats)
    end

    it "with --without two groups" do
      lic! :install, forgotten_command_line_options(:without => "emo test")
      expect(out).to include(lic_show_message)
      expect(out).to include("Gems in the groups emo and test were not installed")
      expect(out).to include(lic_complete_message)
      expect(out).to include("4 Gemfile dependencies, 3 gems now installed.")
    end

    it "with --without more groups" do
      lic! :install, forgotten_command_line_options(:without => "emo obama test")
      expect(out).to include(lic_show_message)
      expect(out).to include("Gems in the groups emo, obama and test were not installed")
      expect(out).to include(lic_complete_message)
      expect(out).to include("4 Gemfile dependencies, 2 gems now installed.")
    end

    describe "with --path and" do
      let(:lic_path) { "./vendor" }

      it "without any options" do
        lic! :install, forgotten_command_line_options(:path => "vendor")
        expect(out).to include(lic_show_path_message)
        expect(out).to_not include("Gems in the group")
        expect(out).to include(lic_complete_message)
      end

      it "with --without one group" do
        lic! :install, forgotten_command_line_options(:without => "emo", :path => "vendor")
        expect(out).to include(lic_show_path_message)
        expect(out).to include("Gems in the group emo were not installed")
        expect(out).to include(lic_complete_message)
      end

      it "with --without two groups" do
        lic! :install, forgotten_command_line_options(:without => "emo test", :path => "vendor")
        expect(out).to include(lic_show_path_message)
        expect(out).to include("Gems in the groups emo and test were not installed")
        expect(out).to include(lic_complete_message)
      end

      it "with --without more groups" do
        lic! :install, forgotten_command_line_options(:without => "emo obama test", :path => "vendor")
        expect(out).to include(lic_show_path_message)
        expect(out).to include("Gems in the groups emo, obama and test were not installed")
        expect(out).to include(lic_complete_message)
      end

      it "with an absolute --path inside the cwd" do
        lic! :install, forgotten_command_line_options(:path => licd_app("cache"))
        expect(out).to include("Bundled gems are installed into `./cache`")
        expect(out).to_not include("Gems in the group")
        expect(out).to include(lic_complete_message)
      end

      it "with an absolute --path outside the cwd" do
        lic! :install, forgotten_command_line_options(:path => tmp("not_licd_app"))
        expect(out).to include("Bundled gems are installed into `#{tmp("not_licd_app")}`")
        expect(out).to_not include("Gems in the group")
        expect(out).to include(lic_complete_message)
      end
    end

    describe "with misspelled or non-existent gem name" do
      it "should report a helpful error message", :lic => "< 2" do
        install_gemfile <<-G
          source "file://localhost#{gem_repo1}"
          gem "rack"
          gem "not-a-gem", :group => :development
        G
        expect(out).to include("Could not find gem 'not-a-gem' in any of the gem sources listed in your Gemfile.")
      end

      it "should report a helpful error message", :lic => "2" do
        install_gemfile <<-G
          source "file://localhost#{gem_repo1}"
          gem "rack"
          gem "not-a-gem", :group => :development
        G
        expect(out).to include normalize_uri_file(<<-EOS.strip)
Could not find gem 'not-a-gem' in rubygems repository file://localhost#{gem_repo1}/ or installed locally.
The source does not contain any versions of 'not-a-gem'
        EOS
      end

      it "should report a helpful error message with reference to cache if available" do
        install_gemfile <<-G
          source "file://localhost#{gem_repo1}"
          gem "rack"
        G
        lic :cache
        expect(licd_app("vendor/cache/rack-1.0.0.gem")).to exist
        install_gemfile <<-G
          source "file://localhost#{gem_repo1}"
          gem "rack"
          gem "not-a-gem", :group => :development
        G
        expect(out).to include("Could not find gem 'not-a-gem' in").
          and include("or in gems cached in vendor/cache.")
      end
    end
  end

  describe "for second lic install run" do
    it "without any options" do
      2.times { lic :install }
      expect(out).to include(lic_show_message)
      expect(out).to_not include("Gems in the groups")
      expect(out).to include(lic_complete_message)
      expect(out).to include(installed_gems_stats)
    end

    it "with --without one group" do
      lic! :install, forgotten_command_line_options(:without => "emo")
      lic! :install
      expect(out).to include(lic_show_message)
      expect(out).to include("Gems in the group emo were not installed")
      expect(out).to include(lic_complete_message)
      expect(out).to include(installed_gems_stats)
    end

    it "with --without two groups" do
      lic! :install, forgotten_command_line_options(:without => "emo test")
      lic! :install
      expect(out).to include(lic_show_message)
      expect(out).to include("Gems in the groups emo and test were not installed")
      expect(out).to include(lic_complete_message)
    end

    it "with --without more groups" do
      lic! :install, forgotten_command_line_options(:without => "emo obama test")
      lic :install
      expect(out).to include(lic_show_message)
      expect(out).to include("Gems in the groups emo, obama and test were not installed")
      expect(out).to include(lic_complete_message)
    end
  end

  describe "for lic update" do
    it "without any options" do
      lic! :update, :all => lic_update_requires_all?
      expect(out).not_to include("Gems in the groups")
      expect(out).to include(lic_updated_message)
    end

    it "with --without one group" do
      lic! :install, forgotten_command_line_options(:without => "emo")
      lic! :update, :all => lic_update_requires_all?
      expect(out).to include("Gems in the group emo were not installed")
      expect(out).to include(lic_updated_message)
    end

    it "with --without two groups" do
      lic! :install, forgotten_command_line_options(:without => "emo test")
      lic! :update, :all => lic_update_requires_all?
      expect(out).to include("Gems in the groups emo and test were not installed")
      expect(out).to include(lic_updated_message)
    end

    it "with --without more groups" do
      lic! :install, forgotten_command_line_options(:without => "emo obama test")
      lic! :update, :all => lic_update_requires_all?
      expect(out).to include("Gems in the groups emo, obama and test were not installed")
      expect(out).to include(lic_updated_message)
    end
  end
end
