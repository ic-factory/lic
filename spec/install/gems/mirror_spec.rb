# frozen_string_literal: true

RSpec.describe "lic install with a mirror configured" do
  describe "when the mirror does not match the gem source" do
    before :each do
      gemfile <<-G
        source "file://localhost#{gem_repo1}"

        gem "rack"
      G
      lic "config --local mirror.http://gems.example.org http://gem-mirror.example.org"
    end

    it "installs from the normal location" do
      lic :install
      expect(out).to include(normalize_uri_file("Fetching source index from file://localhost#{gem_repo1}"))
      expect(the_lic).to include_gems "rack 1.0"
    end
  end

  describe "when the gem source matches a configured mirror" do
    before :each do
      gemfile <<-G
        # This source is bogus and doesn't have the gem we're looking for
        source "file://localhost#{gem_repo2}"

        gem "rack"
      G
      lic "config --local mirror.file://localhost#{gem_repo2} file://localhost#{gem_repo1}"
    end

    it "installs the gem from the mirror" do
      lic :install
      expect(out).to include(normalize_uri_file("Fetching source index from file://localhost#{gem_repo1}"))
      expect(out).not_to include(normalize_uri_file("Fetching source index from file://localhost#{gem_repo2}"))
      expect(the_lic).to include_gems "rack 1.0"
    end
  end
end
