# frozen_string_literal: true

RSpec.describe Lic::Plugin::DSL do
  DSL = Lic::Plugin::DSL

  subject(:dsl) { Lic::Plugin::DSL.new }

  before do
    allow(Lic).to receive(:root) { Pathname.new "/" }
  end

  describe "it ignores only the methods defined in Lic::Dsl" do
    it "doesn't raises error for Dsl methods" do
      expect { dsl.install_if }.not_to raise_error
    end

    it "raises error for other methods" do
      expect { dsl.no_method }.to raise_error(DSL::PluginGemfileError)
    end
  end

  describe "source block" do
    it "adds #source with :type to list and also inferred_plugins list" do
      expect(dsl).to receive(:plugin).with("lic-source-news").once

      dsl.source("some_random_url", :type => "news") {}

      expect(dsl.inferred_plugins).to eq(["lic-source-news"])
    end

    it "registers a source type plugin only once for multiple declataions" do
      expect(dsl).to receive(:plugin).with("lic-source-news").and_call_original.once

      dsl.source("some_random_url", :type => "news") {}
      dsl.source("another_random_url", :type => "news") {}
    end
  end
end
