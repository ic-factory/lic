# frozen_string_literal: true

RSpec.describe "major deprecations", :lic => "< 2" do
  let(:warnings) { last_command.lic_err } # change to err in 2.0
  let(:warnings_without_version_messages) { warnings.gsub(/#{Spec::Matchers::MAJOR_DEPRECATION}Lic will only support ruby(gems)? >= .*/, "") }

  context "in a .99 version" do
    before do
      simulate_lic_version "1.99.1"
      lic "config --delete major_deprecations"
    end

    it "prints major deprecations without being configured" do
      ruby <<-R
        require "lic"
        Lic::SharedHelpers.major_deprecation(Lic::VERSION)
      R

      expect(warnings).to have_major_deprecation("1.99.1")
    end
  end

  before do
    lic "config major_deprecations true"

    create_file "gems.rb", <<-G
      source "file:#{gem_repo1}"
      ruby #{RUBY_VERSION.dump}
      gem "rack"
    G
    lic! "install"
  end

  describe "lic_ruby" do
    it "prints a deprecation" do
      lic_ruby
      warnings.gsub! "\nruby #{RUBY_VERSION}", ""
      expect(warnings).to have_major_deprecation "the lic_ruby executable has been removed in favor of `lic platform --ruby`"
    end
  end

  describe "Lic" do
    describe ".clean_env" do
      it "is deprecated in favor of .unlicd_env" do
        source = "Lic.clean_env"
        lic "exec ruby -e #{source.dump}"
        expect(warnings).to have_major_deprecation \
          "`Lic.clean_env` has been deprecated in favor of `Lic.unlicd_env`. " \
          "If you instead want the environment before lic was originally loaded, use `Lic.original_env`"
      end
    end

    describe ".environment" do
      it "is deprecated in favor of .load" do
        source = "Lic.environment"
        lic "exec ruby -e #{source.dump}"
        expect(warnings).to have_major_deprecation "Lic.environment has been removed in favor of Lic.load"
      end
    end

    shared_examples_for "environmental deprecations" do |trigger|
      describe "ruby version", :ruby => "< 2.0" do
        it "requires a newer ruby version" do
          instance_eval(&trigger)
          expect(warnings).to have_major_deprecation "Lic will only support ruby >= 2.0, you are running #{RUBY_VERSION}"
        end
      end

      describe "rubygems version", :rubygems => "< 2.0" do
        it "requires a newer rubygems version" do
          instance_eval(&trigger)
          expect(warnings).to have_major_deprecation "Lic will only support rubygems >= 2.0, you are running #{Gem::VERSION}"
        end
      end
    end

    describe "-rlic/setup" do
      it_behaves_like "environmental deprecations", proc { ruby "require 'lic/setup'" }
    end

    describe "Lic.setup" do
      it_behaves_like "environmental deprecations", proc { ruby "require 'lic'; Lic.setup" }
    end

    describe "lic check" do
      it_behaves_like "environmental deprecations", proc { lic :check }
    end

    describe "lic update --quiet" do
      it "does not print any deprecations" do
        lic :update, :quiet => true
        expect(warnings_without_version_messages).not_to have_major_deprecation
      end
    end

    describe "lic update" do
      before do
        create_file("gems.rb", "")
        lic! "install"
      end

      it "warns when no options are given" do
        lic! "update"
        expect(warnings).to have_major_deprecation a_string_including("Pass --all to `lic update` to update everything")
      end

      it "does not warn when --all is passed" do
        lic! "update --all"
        expect(warnings_without_version_messages).not_to have_major_deprecation
      end
    end

    describe "lic install --binstubs" do
      it "should output a deprecation warning" do
        gemfile <<-G
          gem 'rack'
        G

        lic :install, :binstubs => true
        expect(warnings).to have_major_deprecation a_string_including("The --binstubs option will be removed")
      end
    end
  end

  context "when lic is run" do
    it "should not warn about gems.rb" do
      create_file "gems.rb", <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G

      lic :install
      expect(warnings_without_version_messages).not_to have_major_deprecation
    end

    it "should print a Gemfile deprecation warning" do
      create_file "gems.rb"
      install_gemfile! <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G
      expect(the_lic).to include_gem "rack 1.0"

      expect(warnings).to have_major_deprecation a_string_including("gems.rb and gems.locked will be preferred to Gemfile and Gemfile.lock.")
    end

    context "with flags" do
      it "should print a deprecation warning about autoremembering flags" do
        install_gemfile <<-G, :path => "vendor/lic"
          source "file://#{gem_repo1}"
          gem "rack"
        G

        expect(warnings).to have_major_deprecation a_string_including(
          "flags passed to commands will no longer be automatically remembered."
        )
      end
    end
  end

  context "when Lic.setup is run in a ruby script" do
    it "should print a single deprecation warning" do
      create_file "gems.rb"
      install_gemfile! <<-G
        source "file://#{gem_repo1}"
        gem "rack", :group => :test
      G

      ruby <<-RUBY
        require 'rubygems'
        require 'lic'
        require 'lic/vendored_thor'

        Lic.ui = Lic::UI::Shell.new
        Lic.setup
        Lic.setup
      RUBY

      expect(warnings_without_version_messages).to have_major_deprecation("gems.rb and gems.locked will be preferred to Gemfile and Gemfile.lock.")
    end
  end

  context "when `lic/deployment` is required in a ruby script" do
    it "should print a capistrano deprecation warning" do
      ruby(<<-RUBY)
        require 'lic/deployment'
      RUBY

      expect(warnings).to have_major_deprecation("Lic no longer integrates " \
                             "with Capistrano, but Capistrano provides " \
                             "its own integration with Lic via the " \
                             "capistrano-lic gem. Use it instead.")
    end
  end

  describe Lic::Dsl do
    before do
      @rubygems = double("rubygems")
      allow(Lic::Source::Rubygems).to receive(:new) { @rubygems }
    end

    context "with github gems" do
      it "warns about the https change" do
        msg = <<-EOS
The :github git source is deprecated, and will be removed in Lic 2.0. Change any "reponame" :github sources to "username/reponame". Add this code to the top of your Gemfile to ensure it continues to work:

    git_source(:github) {|repo_name| "https://github.com/\#{repo_name}.git" }

        EOS
        expect(Lic::SharedHelpers).to receive(:major_deprecation).with(2, msg)
        subject.gem("sparks", :github => "indirect/sparks")
      end

      it "upgrades to https on request" do
        Lic.settings.temporary "github.https" => true
        msg = <<-EOS
The :github git source is deprecated, and will be removed in Lic 2.0. Change any "reponame" :github sources to "username/reponame". Add this code to the top of your Gemfile to ensure it continues to work:

    git_source(:github) {|repo_name| "https://github.com/\#{repo_name}.git" }

        EOS
        expect(Lic::SharedHelpers).to receive(:major_deprecation).with(2, msg)
        expect(Lic::SharedHelpers).to receive(:major_deprecation).with(2, "The `github.https` setting will be removed")
        subject.gem("sparks", :github => "indirect/sparks")
        github_uri = "https://github.com/indirect/sparks.git"
        expect(subject.dependencies.first.source.uri).to eq(github_uri)
      end
    end

    context "with bitbucket gems" do
      it "warns about removal" do
        allow(Lic.ui).to receive(:deprecate)
        msg = <<-EOS
The :bitbucket git source is deprecated, and will be removed in Lic 2.0. Add this code to the top of your Gemfile to ensure it continues to work:

    git_source(:bitbucket) do |repo_name|
      user_name, repo_name = repo_name.split("/")
      repo_name ||= user_name
      "https://\#{user_name}@bitbucket.org/\#{user_name}/\#{repo_name}.git"
    end

        EOS
        expect(Lic::SharedHelpers).to receive(:major_deprecation).with(2, msg)
        subject.gem("not-really-a-gem", :bitbucket => "mcorp/flatlab-rails")
      end
    end

    context "with gist gems" do
      it "warns about removal" do
        allow(Lic.ui).to receive(:deprecate)
        msg = "The :gist git source is deprecated, and will be removed " \
          "in Lic 2.0. Add this code to the top of your Gemfile to ensure it " \
          "continues to work:\n\n    git_source(:gist) {|repo_name| " \
          "\"https://gist.github.com/\#{repo_name}.git\" }\n\n"
        expect(Lic::SharedHelpers).to receive(:major_deprecation).with(2, msg)
        subject.gem("not-really-a-gem", :gist => "1234")
      end
    end
  end

  context "lic show" do
    it "prints a deprecation warning" do
      install_gemfile! <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G

      lic! :show

      warnings.gsub!(/gems included.*?\[DEPRECATED/im, "[DEPRECATED")

      expect(warnings).to have_major_deprecation a_string_including("use `lic list` instead of `lic show`")
    end
  end

  context "lic console" do
    it "prints a deprecation warning" do
      lic "console"

      expect(warnings).to have_major_deprecation \
        a_string_including("lic console will be replaced by `bin/console` generated by `lic gem <name>`")
    end
  end
end
