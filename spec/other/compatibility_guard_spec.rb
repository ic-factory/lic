# frozen_string_literal: true

RSpec.describe "lic compatibility guard" do
  context "when the lic version is 2+" do
    before { simulate_lic_version "2.0.a" }

    context "when running on Ruby < 2.3", :ruby => "< 2.3" do
      before { simulate_rubygems_version "2.6.11" }

      it "raises a friendly error" do
        lic :version
        expect(err).to eq("Lic 2 requires Ruby 2.3 or later. Either install lic 1 or update to a supported Ruby version.")
      end
    end

    context "when running on RubyGems < 2.5", :ruby => ">= 2.5" do
      before { simulate_rubygems_version "1.3.6" }

      it "raises a friendly error" do
        lic :version
        expect(err).to eq("Lic 2 requires RubyGems 2.5 or later. Either install lic 1 or update to a supported RubyGems version.")
      end
    end
  end
end
