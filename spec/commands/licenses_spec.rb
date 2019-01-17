# frozen_string_literal: true

RSpec.describe "lic licenses" do
  before :each do
    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rails"
      gem "with_license"
    G
  end

  it "prints license information for all gems in the lic" do
    lic "licenses"

    expect(out).to include("lic: Unknown")
    expect(out).to include("with_license: MIT")
  end

  it "performs an automatic lic install" do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rails"
      gem "with_license"
      gem "foo"
    G

    lic "config auto_install 1"
    lic :licenses
    expect(out).to include("Installing foo 1.0")
  end
end
