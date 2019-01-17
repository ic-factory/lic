# frozen_string_literal: true

RSpec.describe "process lock spec" do
  describe "when an install operation is already holding a process lock" do
    before { FileUtils.mkdir_p(default_lic_path) }

    it "will not run a second concurrent lic install until the lock is released" do
      thread = Thread.new do
        Lic::ProcessLock.lock(default_lic_path) do
          sleep 1 # ignore quality_spec
          expect(the_lic).not_to include_gems "rack 1.0"
        end
      end

      install_gemfile! <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G

      thread.join
      expect(the_lic).to include_gems "rack 1.0"
    end

    context "when creating a lock raises Errno::ENOTSUP", :ruby => ">= 1.9" do
      before { allow(File).to receive(:open).and_raise(Errno::ENOTSUP) }

      it "skips creating the lock file and yields" do
        processed = false
        Lic::ProcessLock.lock(default_lic_path) { processed = true }

        expect(processed).to eq true
      end
    end
  end
end
