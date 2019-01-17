# frozen_string_literal: true

RSpec.describe "lic install" do
  describe "with --path" do
    before :each do
      build_gem "rack", "1.0.0", :to_system => true do |s|
        s.write "lib/rack.rb", "puts 'FAIL'"
      end

      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G
    end

    it "does not use available system gems with lic --path vendor/lic", :lic => "< 2" do
      lic! :install, forgotten_command_line_options(:path => "vendor/lic")
      expect(the_lic).to include_gems "rack 1.0.0"
    end

    it "handles paths with regex characters in them" do
      dir = licd_app("bun++dle")
      dir.mkpath

      Dir.chdir(dir) do
        lic! :install, forgotten_command_line_options(:path => dir.join("vendor/lic"))
        expect(out).to include("installed into `./vendor/lic`")
      end

      dir.rmtree
    end

    it "prints a warning to let the user know what has happened with lic --path vendor/lic" do
      lic! :install, forgotten_command_line_options(:path => "vendor/lic")
      expect(out).to include("gems are installed into `./vendor/lic`")
    end

    it "disallows --path vendor/lic --system", :lic => "< 2" do
      lic "install --path vendor/lic --system"
      expect(out).to include("Please choose only one option.")
      expect(exitstatus).to eq(15) if exitstatus
    end

    it "remembers to disable system gems after the first time with lic --path vendor/lic", :lic => "< 2" do
      lic "install --path vendor/lic"
      FileUtils.rm_rf licd_app("vendor")
      lic "install"

      expect(vendored_gems("gems/rack-1.0.0")).to be_directory
      expect(the_lic).to include_gems "rack 1.0.0"
    end

    context "with path_relative_to_cwd set to true" do
      before { lic! "config path_relative_to_cwd true" }

      it "installs the lic relatively to current working directory", :lic => "< 2" do
        Dir.chdir(licd_app.parent) do
          lic! "install --gemfile='#{licd_app}/Gemfile' --path vendor/lic"
          expect(out).to include("installed into `./vendor/lic`")
          expect(licd_app("../vendor/lic")).to be_directory
        end
        expect(the_lic).to include_gems "rack 1.0.0"
      end

      it "installs the standalone lic relative to the cwd" do
        Dir.chdir(licd_app.parent) do
          lic! :install, :gemfile => licd_app("Gemfile"), :standalone => true
          expect(out).to include("installed into `./licd_app/lic`")
          expect(licd_app("lic")).to be_directory
          expect(licd_app("lic/ruby")).to be_directory
        end

        lic! "config unset path"

        Dir.chdir(licd_app("subdir").tap(&:mkpath)) do
          lic! :install, :gemfile => licd_app("Gemfile"), :standalone => true
          expect(out).to include("installed into `../lic`")
          expect(licd_app("lic")).to be_directory
          expect(licd_app("lic/ruby")).to be_directory
        end
      end
    end
  end

  describe "when LIC_PATH or the global path config is set" do
    before :each do
      build_lib "rack", "1.0.0", :to_system => true do |s|
        s.write "lib/rack.rb", "raise 'FAIL'"
      end

      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G
    end

    def set_lic_path(type, location)
      if type == :env
        ENV["LIC_PATH"] = location
      elsif type == :global
        lic! "config path #{location}", "no-color" => nil
      end
    end

    [:env, :global].each do |type|
      context "when set via #{type}" do
        it "installs gems to a path if one is specified" do
          set_lic_path(type, licd_app("vendor2").to_s)
          lic! :install, forgotten_command_line_options(:path => "vendor/lic")

          expect(vendored_gems("gems/rack-1.0.0")).to be_directory
          expect(licd_app("vendor2")).not_to be_directory
          expect(the_lic).to include_gems "rack 1.0.0"
        end

        context "with global_path_appends_ruby_scope set", :lic => "2" do
          it "installs gems to ." do
            set_lic_path(type, ".")
            lic! "config --global disable_shared_gems true"

            lic! :install

            paths_to_exist = %w[cache/rack-1.0.0.gem gems/rack-1.0.0 specifications/rack-1.0.0.gemspec].map {|path| licd_app(Lic.ruby_scope, path) }
            expect(paths_to_exist).to all exist
            expect(the_lic).to include_gems "rack 1.0.0"
          end

          it "installs gems to the path" do
            set_lic_path(type, licd_app("vendor").to_s)

            lic! :install

            expect(licd_app("vendor", Lic.ruby_scope, "gems/rack-1.0.0")).to be_directory
            expect(the_lic).to include_gems "rack 1.0.0"
          end

          it "installs gems to the path relative to root when relative" do
            set_lic_path(type, "vendor")

            FileUtils.mkdir_p licd_app("lol")
            Dir.chdir(licd_app("lol")) do
              lic! :install
            end

            expect(licd_app("vendor", Lic.ruby_scope, "gems/rack-1.0.0")).to be_directory
            expect(the_lic).to include_gems "rack 1.0.0"
          end
        end

        context "with global_path_appends_ruby_scope unset", :lic => "< 2" do
          it "installs gems to ." do
            set_lic_path(type, ".")
            lic! "config --global disable_shared_gems true"

            lic! :install

            expect([licd_app("cache/rack-1.0.0.gem"), licd_app("gems/rack-1.0.0"), licd_app("specifications/rack-1.0.0.gemspec")]).to all exist
            expect(the_lic).to include_gems "rack 1.0.0"
          end

          it "installs gems to LIC_PATH with #{type}" do
            set_lic_path(type, licd_app("vendor").to_s)

            lic :install

            expect(licd_app("vendor/gems/rack-1.0.0")).to be_directory
            expect(the_lic).to include_gems "rack 1.0.0"
          end

          it "installs gems to LIC_PATH relative to root when relative" do
            set_lic_path(type, "vendor")

            FileUtils.mkdir_p licd_app("lol")
            Dir.chdir(licd_app("lol")) do
              lic :install
            end

            expect(licd_app("vendor/gems/rack-1.0.0")).to be_directory
            expect(the_lic).to include_gems "rack 1.0.0"
          end
        end
      end
    end

    it "installs gems to LIC_PATH from .lic/config" do
      config "LIC_PATH" => licd_app("vendor/lic").to_s

      lic :install

      expect(vendored_gems("gems/rack-1.0.0")).to be_directory
      expect(the_lic).to include_gems "rack 1.0.0"
    end

    it "sets LIC_PATH as the first argument to lic install" do
      lic! :install, forgotten_command_line_options(:path => "./vendor/lic")

      expect(vendored_gems("gems/rack-1.0.0")).to be_directory
      expect(the_lic).to include_gems "rack 1.0.0"
    end

    it "disables system gems when passing a path to install" do
      # This is so that vendored gems can be distributed to others
      build_gem "rack", "1.1.0", :to_system => true
      lic! :install, forgotten_command_line_options(:path => "./vendor/lic")

      expect(vendored_gems("gems/rack-1.0.0")).to be_directory
      expect(the_lic).to include_gems "rack 1.0.0"
    end

    it "re-installs gems whose extensions have been deleted", :ruby_repo, :rubygems => ">= 2.3" do
      build_lib "very_simple_binary", "1.0.0", :to_system => true do |s|
        s.write "lib/very_simple_binary.rb", "raise 'FAIL'"
      end

      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "very_simple_binary"
      G

      lic! :install, forgotten_command_line_options(:path => "./vendor/lic")

      expect(vendored_gems("gems/very_simple_binary-1.0")).to be_directory
      expect(vendored_gems("extensions")).to be_directory
      expect(the_lic).to include_gems "very_simple_binary 1.0", :source => "remote1"

      vendored_gems("extensions").rmtree

      run "require 'very_simple_binary_c'"
      expect(err).to include("Lic::GemNotFound")

      lic :install, forgotten_command_line_options(:path => "./vendor/lic")

      expect(vendored_gems("gems/very_simple_binary-1.0")).to be_directory
      expect(vendored_gems("extensions")).to be_directory
      expect(the_lic).to include_gems "very_simple_binary 1.0", :source => "remote1"
    end
  end

  describe "to a file" do
    before do
      in_app_root do
        FileUtils.touch "lic"
      end
    end

    it "reports the file exists" do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G

      lic :install, forgotten_command_line_options(:path => "lic")
      expect(out).to include("file already exists")
    end
  end
end
