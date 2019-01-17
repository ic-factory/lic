# frozen_string_literal: true

RSpec.describe Lic::Retry do
  it "return successful result if no errors" do
    attempts = 0
    result = Lic::Retry.new(nil, nil, 3).attempt do
      attempts += 1
      :success
    end
    expect(result).to eq(:success)
    expect(attempts).to eq(1)
  end

  it "returns the first valid result" do
    jobs = [proc { raise "foo" }, proc { :bar }, proc { raise "foo" }]
    attempts = 0
    result = Lic::Retry.new(nil, nil, 3).attempt do
      attempts += 1
      jobs.shift.call
    end
    expect(result).to eq(:bar)
    expect(attempts).to eq(2)
  end

  it "raises the last error" do
    errors = [StandardError, StandardError, StandardError, Lic::GemfileNotFound]
    attempts = 0
    expect do
      Lic::Retry.new(nil, nil, 3).attempt do
        attempts += 1
        raise errors.shift
      end
    end.to raise_error(Lic::GemfileNotFound)
    expect(attempts).to eq(4)
  end

  it "raises exceptions" do
    error = Lic::GemfileNotFound
    attempts = 0
    expect do
      Lic::Retry.new(nil, error).attempt do
        attempts += 1
        raise error
      end
    end.to raise_error(error)
    expect(attempts).to eq(1)
  end

  context "logging" do
    let(:error)           { Lic::GemfileNotFound }
    let(:failure_message) { "Retrying test due to error (2/2): #{error} #{error}" }

    context "with debugging on" do
      it "print error message with newline" do
        allow(Lic.ui).to receive(:debug?).and_return(true)
        expect(Lic.ui).to_not receive(:info)
        expect(Lic.ui).to receive(:warn).with(failure_message, true)

        expect do
          Lic::Retry.new("test", [], 1).attempt do
            raise error
          end
        end.to raise_error(error)
      end
    end

    context "with debugging off" do
      it "print error message with newlines" do
        allow(Lic.ui).to  receive(:debug?).and_return(false)
        expect(Lic.ui).to receive(:info).with("").twice
        expect(Lic.ui).to receive(:warn).with(failure_message, false)

        expect do
          Lic::Retry.new("test", [], 1).attempt do
            raise error
          end
        end.to raise_error(error)
      end
    end
  end
end
