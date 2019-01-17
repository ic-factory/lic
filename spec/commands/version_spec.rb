# frozen_string_literal: true

RSpec.describe "lic version" do
  context "with -v" do
    it "outputs the version", :lic => "< 2" do
      lic! "-v"
      expect(out).to eq("Lic version #{Lic::VERSION}")
    end

    it "outputs the version", :lic => "2" do
      lic! "-v"
      expect(out).to eq(Lic::VERSION)
    end
  end

  context "with --version" do
    it "outputs the version", :lic => "< 2" do
      lic! "--version"
      expect(out).to eq("Lic version #{Lic::VERSION}")
    end

    it "outputs the version", :lic => "2" do
      lic! "--version"
      expect(out).to eq(Lic::VERSION)
    end
  end

  context "with version" do
    it "outputs the version with build metadata", :lic => "< 2" do
      lic! "version"
      expect(out).to match(/\ALic version #{Regexp.escape(Lic::VERSION)} \(\d{4}-\d{2}-\d{2} commit [a-fA-F0-9]{7,}\)\z/)
    end

    it "outputs the version with build metadata", :lic => "2" do
      lic! "version"
      expect(out).to match(/\A#{Regexp.escape(Lic::VERSION)} \(\d{4}-\d{2}-\d{2} commit [a-fA-F0-9]{7,}\)\z/)
    end
  end
end
