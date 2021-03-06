# frozen_string_literal: true

RSpec.shared_examples "lic install --standalone" do
  shared_examples "common functionality" do
    it "still makes the gems available to normal lic" do
      args = expected_gems.map {|k, v| "#{k} #{v}" }
      expect(the_lic).to include_gems(*args)
    end

    it "generates a lic/lic/setup.rb" do
      expect(licd_app("lic/lic/setup.rb")).to exist
    end

    it "makes the gems available without lic" do
      testrb = String.new <<-RUBY
        $:.unshift File.expand_path("lic")
        require "lic/setup"

      RUBY
      expected_gems.each do |k, _|
        testrb << "\nrequire \"#{k}\""
        testrb << "\nputs #{k.upcase}"
      end
      Dir.chdir(licd_app) do
        ruby testrb, :no_lib => true
      end

      expect(out).to eq(expected_gems.values.join("\n"))
    end

    it "works on a different system" do
      FileUtils.mv(licd_app, "#{licd_app}2")

      testrb = String.new <<-RUBY
        $:.unshift File.expand_path("lic")
        require "lic/setup"

      RUBY
      expected_gems.each do |k, _|
        testrb << "\nrequire \"#{k}\""
        testrb << "\nputs #{k.upcase}"
      end
      Dir.chdir("#{licd_app}2") do
        ruby testrb, :no_lib => true
      end

      expect(out).to eq(expected_gems.values.join("\n"))
    end
  end

  describe "with simple gems" do
    before do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rails"
      G
      lic! :install, forgotten_command_line_options(:path => licd_app("lic")).merge(:standalone => true)
    end

    let(:expected_gems) do
      {
        "actionpack" => "2.3.2",
        "rails" => "2.3.2",
      }
    end

    include_examples "common functionality"
  end

  describe "with gems with native extension", :ruby_repo do
    before do
      install_gemfile <<-G, forgotten_command_line_options(:path => licd_app("lic")).merge(:standalone => true)
        source "file://#{gem_repo1}"
        gem "very_simple_binary"
      G
    end

    it "generates a lic/lic/setup.rb with the proper paths", :rubygems => "2.4" do
      expected_path = licd_app("lic/lic/setup.rb")
      extension_line = File.read(expected_path).each_line.find {|line| line.include? "/extensions/" }.strip
      expect(extension_line).to start_with '$:.unshift "#{path}/../#{ruby_engine}/#{ruby_version}/extensions/'
      expect(extension_line).to end_with '/very_simple_binary-1.0"'
    end
  end

  describe "with gem that has an invalid gemspec" do
    before do
      build_git "bar", :gemspec => false do |s|
        s.write "lib/bar/version.rb", %(BAR_VERSION = '1.0')
        s.write "bar.gemspec", <<-G
          lib = File.expand_path('../lib/', __FILE__)
          $:.unshift lib unless $:.include?(lib)
          require 'bar/version'

          Gem::Specification.new do |s|
            s.name        = 'bar'
            s.version     = BAR_VERSION
            s.summary     = 'Bar'
            s.files       = Dir["lib/**/*.rb"]
            s.author      = 'Anonymous'
            s.require_path = [1,2]
          end
        G
      end
      install_gemfile <<-G, forgotten_command_line_options(:path => licd_app("lic")).merge(:standalone => true)
        gem "bar", :git => "#{lib_path("bar-1.0")}"
      G
    end

    it "outputs a helpful error message" do
      expect(out).to include("You have one or more invalid gemspecs that need to be fixed.")
      expect(out).to include("bar 1.0 has an invalid gemspec")
    end
  end

  describe "with a combination of gems and git repos" do
    before do
      build_git "devise", "1.0"

      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rails"
        gem "devise", :git => "#{lib_path("devise-1.0")}"
      G
      lic! :install, forgotten_command_line_options(:path => licd_app("lic")).merge(:standalone => true)
    end

    let(:expected_gems) do
      {
        "actionpack" => "2.3.2",
        "devise" => "1.0",
        "rails" => "2.3.2",
      }
    end

    include_examples "common functionality"
  end

  describe "with groups" do
    before do
      build_git "devise", "1.0"

      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rails"

        group :test do
          gem "rspec"
          gem "rack-test"
        end
      G
      lic! :install, forgotten_command_line_options(:path => licd_app("lic")).merge(:standalone => true)
    end

    let(:expected_gems) do
      {
        "actionpack" => "2.3.2",
        "rails" => "2.3.2",
      }
    end

    include_examples "common functionality"

    it "allows creating a standalone file with limited groups" do
      lic! :install, forgotten_command_line_options(:path => licd_app("lic")).merge(:standalone => "default")

      Dir.chdir(licd_app) do
        load_error_ruby <<-RUBY, "spec", :no_lib => true
          $:.unshift File.expand_path("lic")
          require "lic/setup"

          require "actionpack"
          puts ACTIONPACK
          require "spec"
        RUBY
      end

      expect(last_command.stdout).to eq("2.3.2")
      expect(last_command.stderr).to eq("ZOMG LOAD ERROR")
    end

    it "allows --without to limit the groups used in a standalone" do
      lic! :install, forgotten_command_line_options(:path => licd_app("lic"), :without => "test").merge(:standalone => true)

      Dir.chdir(licd_app) do
        load_error_ruby <<-RUBY, "spec", :no_lib => true
          $:.unshift File.expand_path("lic")
          require "lic/setup"

          require "actionpack"
          puts ACTIONPACK
          require "spec"
        RUBY
      end

      expect(last_command.stdout).to eq("2.3.2")
      expect(last_command.stderr).to eq("ZOMG LOAD ERROR")
    end

    it "allows --path to change the location of the standalone lic", :lic => "< 2" do
      lic! "install", forgotten_command_line_options(:path => "path/to/lic").merge(:standalone => true)

      Dir.chdir(licd_app) do
        ruby <<-RUBY, :no_lib => true
          $:.unshift File.expand_path("path/to/lic")
          require "lic/setup"

          require "actionpack"
          puts ACTIONPACK
        RUBY
      end

      expect(last_command.stdout).to eq("2.3.2")
    end

    it "allows --path to change the location of the standalone lic", :lic => "2" do
      lic! "install", forgotten_command_line_options(:path => "path/to/lic").merge(:standalone => true)
      path = File.expand_path("path/to/lic")

      Dir.chdir(licd_app) do
        ruby <<-RUBY, :no_lib => true
          $:.unshift File.expand_path(#{path.dump})
          require "lic/setup"

          require "actionpack"
          puts ACTIONPACK
        RUBY
      end

      expect(last_command.stdout).to eq("2.3.2")
    end

    it "allows remembered --without to limit the groups used in a standalone" do
      lic! :install, forgotten_command_line_options(:without => "test")
      lic! :install, forgotten_command_line_options(:path => licd_app("lic")).merge(:standalone => true)

      Dir.chdir(licd_app) do
        load_error_ruby <<-RUBY, "spec", :no_lib => true
          $:.unshift File.expand_path("lic")
          require "lic/setup"

          require "actionpack"
          puts ACTIONPACK
          require "spec"
        RUBY
      end

      expect(last_command.stdout).to eq("2.3.2")
      expect(last_command.stderr).to eq("ZOMG LOAD ERROR")
    end
  end

  describe "with gemcutter's dependency API" do
    let(:source_uri) { "http://localgemserver.test" }

    describe "simple gems" do
      before do
        gemfile <<-G
          source "#{source_uri}"
          gem "rails"
        G
        lic! :install, forgotten_command_line_options(:path => licd_app("lic")).merge(:standalone => true, :artifice => "endpoint")
      end

      let(:expected_gems) do
        {
          "actionpack" => "2.3.2",
          "rails" => "2.3.2",
        }
      end

      include_examples "common functionality"
    end
  end

  describe "with --binstubs", :lic => "< 2" do
    before do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rails"
      G
      lic! :install, forgotten_command_line_options(:path => licd_app("lic")).merge(:standalone => true, :binstubs => true)
    end

    let(:expected_gems) do
      {
        "actionpack" => "2.3.2",
        "rails" => "2.3.2",
      }
    end

    include_examples "common functionality"

    it "creates stubs that use the standalone load path" do
      Dir.chdir(licd_app) do
        expect(`bin/rails -v`.chomp).to eql "2.3.2"
      end
    end

    it "creates stubs that can be executed from anywhere" do
      require "tmpdir"
      Dir.chdir(Dir.tmpdir) do
        sys_exec!(%(#{licd_app("bin/rails")} -v))
        expect(out).to eq("2.3.2")
      end
    end

    it "creates stubs that can be symlinked" do
      pending "File.symlink is unsupported on Windows" if Lic::WINDOWS

      symlink_dir = tmp("symlink")
      FileUtils.mkdir_p(symlink_dir)
      symlink = File.join(symlink_dir, "rails")

      File.symlink(licd_app("bin/rails"), symlink)
      sys_exec!("#{symlink} -v")
      expect(out).to eq("2.3.2")
    end

    it "creates stubs with the correct load path" do
      extension_line = File.read(licd_app("bin/rails")).each_line.find {|line| line.include? "$:.unshift" }.strip
      expect(extension_line).to eq %($:.unshift File.expand_path "../../lic", path.realpath)
    end
  end
end

RSpec.describe "lic install --standalone" do
  include_examples("lic install --standalone")
end

RSpec.describe "lic install --standalone run in a subdirectory" do
  before do
    Dir.chdir(licd_app("bob").tap(&:mkpath))
  end

  include_examples("lic install --standalone")
end
