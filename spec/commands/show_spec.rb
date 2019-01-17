# frozen_string_literal: true

RSpec.describe "lic show" do
  context "with a standard Gemfile" do
    before :each do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rails"
      G
    end

    it "creates a Gemfile.lock if one did not exist" do
      FileUtils.rm("Gemfile.lock")

      lic "show"

      expect(licd_app("Gemfile.lock")).to exist
    end

    it "creates a Gemfile.lock when invoked with a gem name" do
      FileUtils.rm("Gemfile.lock")

      lic "show rails"

      expect(licd_app("Gemfile.lock")).to exist
    end

    it "prints path if gem exists in lic", :lic => "< 2" do
      lic "show rails"
      expect(out).to eq(default_lic_path("gems", "rails-2.3.2").to_s)
    end

    it "prints path if gem exists in lic", :lic => "2" do
      lic "show rails"
      expect(out).to eq(
        "[DEPRECATED FOR 2.0] use `lic info rails` instead of `lic show rails`\n" +
        default_lic_path("gems", "rails-2.3.2").to_s
      )
    end

    it "prints path if gem exists in lic (with --paths option)", :lic => "< 2" do
      lic "show rails --paths"
      expect(out).to eq(default_lic_path("gems", "rails-2.3.2").to_s)
    end

    it "prints path if gem exists in lic (with --paths option)", :lic => "2" do
      lic "show rails --paths"
      expect(out).to eq(
        "[DEPRECATED FOR 2.0] use `lic info rails --path` instead of `lic show rails --paths`\n" +
        default_lic_path("gems", "rails-2.3.2").to_s
      )
    end

    it "warns if path no longer exists on disk" do
      FileUtils.rm_rf(default_lic_path("gems", "rails-2.3.2"))

      lic "show rails"

      expect(out).to match(/has been deleted/i).
        and include(default_lic_path("gems", "rails-2.3.2").to_s)
    end

    it "prints the path to the running lic", :lic => "< 2" do
      lic "show lic"
      expect(out).to eq(root.to_s)
    end

    it "prints the path to the running lic", :lic => "2" do
      lic "show lic"
      expect(out).to eq(
        "[DEPRECATED FOR 2.0] use `lic info lic` instead of `lic show lic`\n" +
        root.to_s
      )
    end

    it "complains if gem not in lic" do
      lic "show missing"
      expect(out).to match(/could not find gem 'missing'/i)
    end

    it "prints path of all gems in lic sorted by name", :lic => "< 2" do
      lic "show --paths"

      expect(out).to include(default_lic_path("gems", "rake-10.0.2").to_s)
      expect(out).to include(default_lic_path("gems", "rails-2.3.2").to_s)

      # Gem names are the last component of their path.
      gem_list = out.split.map {|p| p.split("/").last }
      expect(gem_list).to eq(gem_list.sort)
    end

    it "prints path of all gems in lic sorted by name", :lic => "2" do
      lic "show --paths"

      expect(out).to include(default_lic_path("gems", "rake-10.0.2").to_s)
      expect(out).to include(default_lic_path("gems", "rails-2.3.2").to_s)

      out_lines = out.split("\n")
      expect(out_lines[0]).to eq("[DEPRECATED FOR 2.0] use `lic list` instead of `lic show --paths`")

      # Gem names are the last component of their path.
      gem_list = out_lines[1..-1].map {|p| p.split("/").last }
      expect(gem_list).to eq(gem_list.sort)
    end

    it "prints summary of gems" do
      lic "show --verbose"

      expect(out).to include("* actionmailer (2.3.2)")
      expect(out).to include("\tSummary:  This is just a fake gem for testing")
      expect(out).to include("\tHomepage: No website available.")
      expect(out).to include("\tStatus:   Up to date")
    end
  end

  context "with a git repo in the Gemfile" do
    before :each do
      @git = build_git "foo", "1.0"
    end

    it "prints out git info" do
      install_gemfile <<-G
        gem "foo", :git => "#{lib_path("foo-1.0")}"
      G
      expect(the_lic).to include_gems "foo 1.0"

      lic :show
      expect(out).to include("foo (1.0 #{@git.ref_for("master", 6)}")
    end

    it "prints out branch names other than master" do
      update_git "foo", :branch => "omg" do |s|
        s.write "lib/foo.rb", "FOO = '1.0.omg'"
      end
      @revision = revision_for(lib_path("foo-1.0"))[0...6]

      install_gemfile <<-G
        gem "foo", :git => "#{lib_path("foo-1.0")}", :branch => "omg"
      G
      expect(the_lic).to include_gems "foo 1.0.omg"

      lic :show
      expect(out).to include("foo (1.0 #{@git.ref_for("omg", 6)}")
    end

    it "doesn't print the branch when tied to a ref" do
      sha = revision_for(lib_path("foo-1.0"))
      install_gemfile <<-G
        gem "foo", :git => "#{lib_path("foo-1.0")}", :ref => "#{sha}"
      G

      lic :show
      expect(out).to include("foo (1.0 #{sha[0..6]})")
    end

    it "handles when a version is a '-' prerelease", :rubygems => "2.1" do
      @git = build_git("foo", "1.0.0-beta.1", :path => lib_path("foo"))
      install_gemfile <<-G
        gem "foo", "1.0.0-beta.1", :git => "#{lib_path("foo")}"
      G
      expect(the_lic).to include_gems "foo 1.0.0.pre.beta.1"

      lic! :show
      expect(out).to include("foo (1.0.0.pre.beta.1")
    end
  end

  context "in a fresh gem in a blank git repo" do
    before :each do
      build_git "foo", :path => lib_path("foo")
      in_app_root_custom lib_path("foo")
      File.open("Gemfile", "w") {|f| f.puts "gemspec" }
      sys_exec "rm -rf .git && git init"
    end

    it "does not output git errors" do
      lic :show
      expect(err).to lack_errors
    end
  end

  it "performs an automatic lic install" do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "foo"
    G

    lic "config auto_install 1"
    lic :show
    expect(out).to include("Installing foo 1.0")
  end

  context "with an invalid regexp for gem name" do
    it "does not find the gem" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rails"
      G

      invalid_regexp = "[]"

      lic "show #{invalid_regexp}"
      expect(out).to include("Could not find gem '#{invalid_regexp}'.")
    end
  end

  context "--outdated option" do
    # Regression test for https://github.com/lic/lic/issues/5375
    before do
      build_repo2
    end

    it "doesn't update gems to newer versions" do
      install_gemfile! <<-G
        source "file://#{gem_repo2}"
        gem "rails"
      G

      expect(the_lic).to include_gem("rails 2.3.2")

      update_repo2 do
        build_gem "rails", "3.0.0" do |s|
          s.executables = "rails"
        end
      end

      lic! "show --outdated"

      lic! "install"
      expect(the_lic).to include_gem("rails 2.3.2")
    end
  end
end
