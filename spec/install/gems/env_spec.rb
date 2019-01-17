# frozen_string_literal: true

RSpec.describe "lic install with ENV conditionals" do
  describe "when just setting an ENV key as a string" do
    before :each do
      gemfile <<-G
        source "file://#{gem_repo1}"

        env "LIC_TEST" do
          gem "rack"
        end
      G
    end

    it "excludes the gems when the ENV variable is not set" do
      lic :install
      expect(the_lic).not_to include_gems "rack"
    end

    it "includes the gems when the ENV variable is set" do
      ENV["LIC_TEST"] = "1"
      lic :install
      expect(the_lic).to include_gems "rack 1.0"
    end
  end

  describe "when just setting an ENV key as a symbol" do
    before :each do
      gemfile <<-G
        source "file://#{gem_repo1}"

        env :LIC_TEST do
          gem "rack"
        end
      G
    end

    it "excludes the gems when the ENV variable is not set" do
      lic :install
      expect(the_lic).not_to include_gems "rack"
    end

    it "includes the gems when the ENV variable is set" do
      ENV["LIC_TEST"] = "1"
      lic :install
      expect(the_lic).to include_gems "rack 1.0"
    end
  end

  describe "when setting a string to match the env" do
    before :each do
      gemfile <<-G
        source "file://#{gem_repo1}"

        env "LIC_TEST" => "foo" do
          gem "rack"
        end
      G
    end

    it "excludes the gems when the ENV variable is not set" do
      lic :install
      expect(the_lic).not_to include_gems "rack"
    end

    it "excludes the gems when the ENV variable is set but does not match the condition" do
      ENV["LIC_TEST"] = "1"
      lic :install
      expect(the_lic).not_to include_gems "rack"
    end

    it "includes the gems when the ENV variable is set and matches the condition" do
      ENV["LIC_TEST"] = "foo"
      lic :install
      expect(the_lic).to include_gems "rack 1.0"
    end
  end

  describe "when setting a regex to match the env" do
    before :each do
      gemfile <<-G
        source "file://#{gem_repo1}"

        env "LIC_TEST" => /foo/ do
          gem "rack"
        end
      G
    end

    it "excludes the gems when the ENV variable is not set" do
      lic :install
      expect(the_lic).not_to include_gems "rack"
    end

    it "excludes the gems when the ENV variable is set but does not match the condition" do
      ENV["LIC_TEST"] = "fo"
      lic :install
      expect(the_lic).not_to include_gems "rack"
    end

    it "includes the gems when the ENV variable is set and matches the condition" do
      ENV["LIC_TEST"] = "foobar"
      lic :install
      expect(the_lic).to include_gems "rack 1.0"
    end
  end
end
