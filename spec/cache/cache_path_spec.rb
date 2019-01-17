# frozen_string_literal: true

RSpec.describe "lic package" do
  before do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G
  end

  context "with --cache-path" do
    it "caches gems at given path" do
      lic :package, "cache-path" => "vendor/cache-foo"
      expect(licd_app("vendor/cache-foo/rack-1.0.0.gem")).to exist
    end
  end

  context "with config cache_path" do
    it "caches gems at given path" do
      lic "config cache_path vendor/cache-foo"
      lic :package
      expect(licd_app("vendor/cache-foo/rack-1.0.0.gem")).to exist
    end
  end

  context "with absolute --cache-path" do
    it "caches gems at given path" do
      lic :package, "cache-path" => "/tmp/cache-foo"
      expect(licd_app("/tmp/cache-foo/rack-1.0.0.gem")).to exist
    end
  end
end
