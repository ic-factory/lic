# frozen_string_literal: true

RSpec.describe "lic issue" do
  it "exits with a message" do
    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rails"
    G

    lic "issue"
    expect(out).to include "Did you find an issue with Lic?"
    expect(out).to include "## Environment"
    expect(out).to include "## Gemfile"
    expect(out).to include "## Bundle Doctor"
  end
end
