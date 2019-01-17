# frozen_string_literal: true

RSpec.describe "lic install with a lockfile present" do
  let(:gf) { <<-G }
    source "file://#{gem_repo1}"

    gem "rack", "1.0.0"
  G

  subject do
    install_gemfile(gf)
  end

  context "gemfile evaluation" do
    let(:gf) { super() + "\n\n File.open('evals', 'a') {|f| f << %(1\n) } unless ENV['LIC_SPEC_NO_APPEND']" }

    context "with plugins disabled" do
      before do
        lic! "config plugins false"
        subject
      end

      it "does not evaluate the gemfile twice" do
        lic! :install

        with_env_vars("LIC_SPEC_NO_APPEND" => "1") { expect(the_lic).to include_gem "rack 1.0.0" }

        # The first eval is from the initial install, we're testing that the
        # second install doesn't double-eval
        expect(licd_app("evals").read.lines.to_a.size).to eq(2)
      end

      context "when the gem is not installed" do
        before { FileUtils.rm_rf ".lic" }

        it "does not evaluate the gemfile twice" do
          lic! :install

          with_env_vars("LIC_SPEC_NO_APPEND" => "1") { expect(the_lic).to include_gem "rack 1.0.0" }

          # The first eval is from the initial install, we're testing that the
          # second install doesn't double-eval
          expect(licd_app("evals").read.lines.to_a.size).to eq(2)
        end
      end
    end
  end
end
