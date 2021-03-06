# frozen_string_literal: true

RSpec.describe Lic::Plugin::Events do
  context "plugin events" do
    describe "#define" do
      it "raises when redefining a constant" do
        expect do
          Lic::Plugin::Events.send(:define, :GEM_BEFORE_INSTALL_ALL, "another-value")
        end.to raise_error(ArgumentError)
      end

      it "can define a new constant" do
        Lic::Plugin::Events.send(:define, :NEW_CONSTANT, "value")
        expect(Lic::Plugin::Events::NEW_CONSTANT).to eq("value")
      end
    end
  end
end
