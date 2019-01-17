# frozen_string_literal: true

require "lic/psyched_yaml"

RSpec.describe "Lic::YamlLibrarySyntaxError" do
  it "is raised on YAML parse errors" do
    expect { YAML.parse "{foo" }.to raise_error(Lic::YamlLibrarySyntaxError)
  end
end
