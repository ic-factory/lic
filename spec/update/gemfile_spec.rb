# frozen_string_literal: true

RSpec.describe "lic update" do
  context "with --gemfile" do
    it "finds the gemfile" do
      gemfile licd_app("NotGemfile"), <<-G
        source "file://#{gem_repo1}"
        gem 'rack'
      G

      lic! :install, :gemfile => licd_app("NotGemfile")
      lic! :update, :gemfile => licd_app("NotGemfile"), :all => lic_update_requires_all?

      # Specify LIC_GEMFILE for `the_lic`
      # to retrieve the proper Gemfile
      ENV["LIC_GEMFILE"] = "NotGemfile"
      expect(the_lic).to include_gems "rack 1.0.0"
    end
  end

  context "with gemfile set via config" do
    before do
      gemfile licd_app("NotGemfile"), <<-G
        source "file://#{gem_repo1}"
        gem 'rack'
      G

      lic "config --local gemfile #{licd_app("NotGemfile")}"
      lic! :install
    end

    it "uses the gemfile to update" do
      lic! "update", :all => lic_update_requires_all?
      lic "list"

      expect(out).to include("rack (1.0.0)")
    end

    it "uses the gemfile while in a subdirectory" do
      licd_app("subdir").mkpath
      Dir.chdir(licd_app("subdir")) do
        lic! "update", :all => lic_update_requires_all?
        lic "list"

        expect(out).to include("rack (1.0.0)")
      end
    end
  end

  context "with prefer_gems_rb set" do
    before { lic! "config prefer_gems_rb true" }

    it "prefers gems.rb to Gemfile" do
      create_file("gems.rb", "gem 'lic'")
      create_file("Gemfile", "raise 'wrong Gemfile!'")

      lic! :install
      lic! :update, :all => lic_update_requires_all?

      expect(licd_app("gems.rb")).to be_file
      expect(licd_app("Gemfile.lock")).not_to be_file

      expect(the_lic).to include_gem "lic #{Lic::VERSION}"
    end
  end
end
