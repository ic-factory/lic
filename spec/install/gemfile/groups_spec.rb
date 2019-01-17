# frozen_string_literal: true

RSpec.describe "lic install with groups" do
  describe "installing with no options" do
    before :each do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
        group :emo do
          gem "activesupport", "2.3.5"
        end
        gem "thin", :groups => [:emo]
      G
    end

    it "installs gems in the default group" do
      expect(the_lic).to include_gems "rack 1.0.0"
    end

    it "installs gems in a group block into that group" do
      expect(the_lic).to include_gems "activesupport 2.3.5"

      load_error_run <<-R, "activesupport", :default
        require 'activesupport'
        puts ACTIVESUPPORT
      R

      expect(err).to eq_err("ZOMG LOAD ERROR")
    end

    it "installs gems with inline :groups into those groups" do
      expect(the_lic).to include_gems "thin 1.0"

      load_error_run <<-R, "thin", :default
        require 'thin'
        puts THIN
      R

      expect(err).to eq_err("ZOMG LOAD ERROR")
    end

    it "sets up everything if Lic.setup is used with no groups" do
      output = run("require 'rack'; puts RACK")
      expect(output).to eq("1.0.0")

      output = run("require 'activesupport'; puts ACTIVESUPPORT")
      expect(output).to eq("2.3.5")

      output = run("require 'thin'; puts THIN")
      expect(output).to eq("1.0")
    end

    it "removes old groups when new groups are set up" do
      load_error_run <<-RUBY, "thin", :emo
        Lic.setup(:default)
        require 'thin'
        puts THIN
      RUBY

      expect(err).to eq_err("ZOMG LOAD ERROR")
    end

    it "sets up old groups when they have previously been removed" do
      output = run <<-RUBY, :emo
        Lic.setup(:default)
        Lic.setup(:default, :emo)
        require 'thin'; puts THIN
      RUBY
      expect(output).to eq("1.0")
    end
  end

  describe "installing --without" do
    describe "with gems assigned to a single group" do
      before :each do
        gemfile <<-G
          source "file://#{gem_repo1}"
          gem "rack"
          group :emo do
            gem "activesupport", "2.3.5"
          end
          group :debugging, :optional => true do
            gem "thin"
          end
        G
      end

      it "installs gems in the default group" do
        lic! :install, forgotten_command_line_options(:without => "emo")
        expect(the_lic).to include_gems "rack 1.0.0", :groups => [:default]
      end

      it "does not install gems from the excluded group" do
        lic :install, :without => "emo"
        expect(the_lic).not_to include_gems "activesupport 2.3.5", :groups => [:default]
      end

      it "does not install gems from the previously excluded group" do
        lic :install, forgotten_command_line_options(:without => "emo")
        expect(the_lic).not_to include_gems "activesupport 2.3.5"
        lic :install
        expect(the_lic).not_to include_gems "activesupport 2.3.5"
      end

      it "does not say it installed gems from the excluded group" do
        lic! :install, forgotten_command_line_options(:without => "emo")
        expect(out).not_to include("activesupport")
      end

      it "allows Lic.setup for specific groups" do
        lic :install, forgotten_command_line_options(:without => "emo")
        run!("require 'rack'; puts RACK", :default)
        expect(out).to eq("1.0.0")
      end

      it "does not effect the resolve" do
        gemfile <<-G
          source "file://#{gem_repo1}"
          gem "activesupport"
          group :emo do
            gem "rails", "2.3.2"
          end
        G

        lic :install, forgotten_command_line_options(:without => "emo")
        expect(the_lic).to include_gems "activesupport 2.3.2", :groups => [:default]
      end

      it "still works on a different machine and excludes gems" do
        lic :install, forgotten_command_line_options(:without => "emo")

        simulate_new_machine
        lic :install, forgotten_command_line_options(:without => "emo")

        expect(the_lic).to include_gems "rack 1.0.0", :groups => [:default]
        expect(the_lic).not_to include_gems "activesupport 2.3.5", :groups => [:default]
      end

      it "still works when LIC_WITHOUT is set" do
        ENV["LIC_WITHOUT"] = "emo"

        lic :install
        expect(out).not_to include("activesupport")

        expect(the_lic).to include_gems "rack 1.0.0", :groups => [:default]
        expect(the_lic).not_to include_gems "activesupport 2.3.5", :groups => [:default]

        ENV["LIC_WITHOUT"] = nil
      end

      it "clears without when passed an empty list" do
        lic :install, forgotten_command_line_options(:without => "emo")

        lic :install, forgotten_command_line_options(:without => "")
        expect(the_lic).to include_gems "activesupport 2.3.5"
      end

      it "doesn't clear without when nothing is passed" do
        lic :install, forgotten_command_line_options(:without => "emo")

        lic :install
        expect(the_lic).not_to include_gems "activesupport 2.3.5"
      end

      it "does not install gems from the optional group" do
        lic :install
        expect(the_lic).not_to include_gems "thin 1.0"
      end

      it "does install gems from the optional group when requested" do
        lic :install, forgotten_command_line_options(:with => "debugging")
        expect(the_lic).to include_gems "thin 1.0"
      end

      it "does install gems from the previously requested group" do
        lic :install, forgotten_command_line_options(:with => "debugging")
        expect(the_lic).to include_gems "thin 1.0"
        lic :install
        expect(the_lic).to include_gems "thin 1.0"
      end

      it "does install gems from the optional groups requested with LIC_WITH" do
        ENV["LIC_WITH"] = "debugging"
        lic :install
        expect(the_lic).to include_gems "thin 1.0"
        ENV["LIC_WITH"] = nil
      end

      it "clears with when passed an empty list" do
        lic :install, forgotten_command_line_options(:with => "debugging")
        lic :install, forgotten_command_line_options(:with => "")
        expect(the_lic).not_to include_gems "thin 1.0"
      end

      it "does remove groups from without when passed at --with", :lic => "< 2" do
        lic :install, forgotten_command_line_options(:without => "emo")
        lic :install, forgotten_command_line_options(:with => "emo")
        expect(the_lic).to include_gems "activesupport 2.3.5"
      end

      it "does remove groups from with when passed at --without", :lic => "< 2" do
        lic :install, forgotten_command_line_options(:with => "debugging")
        lic :install, forgotten_command_line_options(:without => "debugging")
        expect(the_lic).not_to include_gem "thin 1.0"
      end

      it "errors out when passing a group to with and without via CLI flags", :lic => "< 2" do
        lic :install, forgotten_command_line_options(:with => "emo debugging", :without => "emo")
        expect(last_command).to be_failure
        expect(out).to include("The offending groups are: emo")
      end

      it "allows the LIC_WITH setting to override LIC_WITHOUT" do
        ENV["LIC_WITH"] = "debugging"

        lic! :install
        expect(the_lic).to include_gem "thin 1.0"

        ENV["LIC_WITHOUT"] = "debugging"
        expect(the_lic).to include_gem "thin 1.0"

        lic! :install
        expect(the_lic).to include_gem "thin 1.0"
      end

      it "can add and remove a group at the same time" do
        lic :install, forgotten_command_line_options(:with => "debugging", :without => "emo")
        expect(the_lic).to include_gems "thin 1.0"
        expect(the_lic).not_to include_gems "activesupport 2.3.5"
      end

      it "does have no effect when listing a not optional group in with" do
        lic :install, forgotten_command_line_options(:with => "emo")
        expect(the_lic).to include_gems "activesupport 2.3.5"
      end

      it "does have no effect when listing an optional group in without" do
        lic :install, forgotten_command_line_options(:without => "debugging")
        expect(the_lic).not_to include_gems "thin 1.0"
      end
    end

    describe "with gems assigned to multiple groups" do
      before :each do
        gemfile <<-G
          source "file://#{gem_repo1}"
          gem "rack"
          group :emo, :lolercoaster do
            gem "activesupport", "2.3.5"
          end
        G
      end

      it "installs gems in the default group" do
        lic! :install, forgotten_command_line_options(:without => "emo lolercoaster")
        expect(the_lic).to include_gems "rack 1.0.0"
      end

      it "installs the gem if any of its groups are installed" do
        lic! :install, forgotten_command_line_options(:without => "emo")
        expect(the_lic).to include_gems "rack 1.0.0", "activesupport 2.3.5"
      end

      describe "with a gem defined multiple times in different groups" do
        before :each do
          gemfile <<-G
            source "file://#{gem_repo1}"
            gem "rack"

            group :emo do
              gem "activesupport", "2.3.5"
            end

            group :lolercoaster do
              gem "activesupport", "2.3.5"
            end
          G
        end

        it "installs the gem w/ option --without emo" do
          lic :install, forgotten_command_line_options(:without => "emo")
          expect(the_lic).to include_gems "activesupport 2.3.5"
        end

        it "installs the gem w/ option --without lolercoaster" do
          lic :install, forgotten_command_line_options(:without => "lolercoaster")
          expect(the_lic).to include_gems "activesupport 2.3.5"
        end

        it "does not install the gem w/ option --without emo lolercoaster" do
          lic :install, forgotten_command_line_options(:without => "emo lolercoaster")
          expect(the_lic).not_to include_gems "activesupport 2.3.5"
        end

        it "does not install the gem w/ option --without 'emo lolercoaster'" do
          lic :install, forgotten_command_line_options(:without => "'emo lolercoaster'")
          expect(the_lic).not_to include_gems "activesupport 2.3.5"
        end
      end
    end

    describe "nesting groups" do
      before :each do
        gemfile <<-G
          source "file://#{gem_repo1}"
          gem "rack"
          group :emo do
            group :lolercoaster do
              gem "activesupport", "2.3.5"
            end
          end
        G
      end

      it "installs gems in the default group" do
        lic! :install, forgotten_command_line_options(:without => "emo lolercoaster")
        expect(the_lic).to include_gems "rack 1.0.0"
      end

      it "installs the gem if any of its groups are installed" do
        lic! :install, forgotten_command_line_options(:without => "emo")
        expect(the_lic).to include_gems "rack 1.0.0", "activesupport 2.3.5"
      end
    end
  end

  describe "when loading only the default group" do
    it "should not load all groups" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
        gem "activesupport", :groups => :development
      G

      ruby <<-R
        require "lic"
        Lic.setup :default
        Lic.require :default
        puts RACK
        begin
          require "activesupport"
        rescue LoadError
          puts "no activesupport"
        end
      R

      expect(out).to include("1.0")
      expect(out).to include("no activesupport")
    end
  end

  describe "when locked and installed with --without" do
    before(:each) do
      build_repo2
      system_gems "rack-0.9.1" do
        install_gemfile <<-G, forgotten_command_line_options(:without => "rack")
          source "file://#{gem_repo2}"
          gem "rack"

          group :rack do
            gem "rack_middleware"
          end
        G
      end
    end

    it "uses the correct versions even if --without was used on the original" do
      expect(the_lic).to include_gems "rack 0.9.1"
      expect(the_lic).not_to include_gems "rack_middleware 1.0"
      simulate_new_machine

      lic :install

      expect(the_lic).to include_gems "rack 0.9.1"
      expect(the_lic).to include_gems "rack_middleware 1.0"
    end

    it "does not hit the remote a second time" do
      FileUtils.rm_rf gem_repo2
      lic! :install, forgotten_command_line_options(:without => "rack").merge(:verbose => true)
      expect(last_command.stdboth).not_to match(/fetching/i)
    end
  end
end
