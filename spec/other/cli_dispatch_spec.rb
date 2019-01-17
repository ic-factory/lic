# frozen_string_literal: true

RSpec.describe "lic command names" do
  it "work when given fully" do
    lic "install"
    expect(last_command.lic_err).to eq("Could not locate Gemfile")
    expect(last_command.stdboth).not_to include("Ambiguous command")
  end

  it "work when not ambiguous" do
    lic "ins"
    expect(last_command.lic_err).to eq("Could not locate Gemfile")
    expect(last_command.stdboth).not_to include("Ambiguous command")
  end

  it "print a friendly error when ambiguous" do
    lic "in"
    expect(last_command.lic_err).to eq("Ambiguous command in matches [info, init, inject, install]")
  end

  context "when cache_command_is_package is set" do
    before { lic! "config cache_command_is_package true" }

    it "dispatches `lic cache` to the package command" do
      lic "cache --verbose"
      expect(last_command.stdout).to start_with "Running `lic package --verbose`"
    end
  end
end
