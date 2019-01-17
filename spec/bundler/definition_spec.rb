# frozen_string_literal: true

require "lic/definition"

RSpec.describe Lic::Definition do
  describe "#lock" do
    before do
      allow(Lic).to receive(:settings) { Lic::Settings.new(".") }
      allow(Lic::SharedHelpers).to receive(:find_gemfile) { Pathname.new("Gemfile") }
      allow(Lic).to receive(:ui) { double("UI", :info => "", :debug => "") }
    end
    context "when it's not possible to write to the file" do
      subject { Lic::Definition.new(nil, [], Lic::SourceList.new, []) }

      it "raises an PermissionError with explanation" do
        allow(File).to receive(:open).and_call_original
        expect(File).to receive(:open).with("Gemfile.lock", "wb").
          and_raise(Errno::EACCES)
        expect { subject.lock("Gemfile.lock") }.
          to raise_error(Lic::PermissionError, /Gemfile\.lock/)
      end
    end
    context "when a temporary resource access issue occurs" do
      subject { Lic::Definition.new(nil, [], Lic::SourceList.new, []) }

      it "raises a TemporaryResourceError with explanation" do
        allow(File).to receive(:open).and_call_original
        expect(File).to receive(:open).with("Gemfile.lock", "wb").
          and_raise(Errno::EAGAIN)
        expect { subject.lock("Gemfile.lock") }.
          to raise_error(Lic::TemporaryResourceError, /temporarily unavailable/)
      end
    end
  end

  describe "detects changes" do
    it "for a path gem with changes", :lic => "< 2" do
      build_lib "foo", "1.0", :path => lib_path("foo")

      install_gemfile <<-G
        source "file://localhost#{gem_repo1}"
        gem "foo", :path => "#{lib_path("foo")}"
      G

      build_lib "foo", "1.0", :path => lib_path("foo") do |s|
        s.add_dependency "rack", "1.0"
      end

      lic :install, :env => { "DEBUG" => 1 }

      expect(out).to match(/re-resolving dependencies/)
      lockfile_should_be <<-G
        PATH
          remote: #{lib_path("foo")}
          specs:
            foo (1.0)
              rack (= 1.0)

        GEM
          remote: file://localhost#{gem_repo1}/
          specs:
            rack (1.0.0)

        PLATFORMS
          ruby

        DEPENDENCIES
          foo!

        LICD WITH
           #{Lic::VERSION}
      G
    end

    it "for a path gem with changes", :lic => "2" do
      build_lib "foo", "1.0", :path => lib_path("foo")

      install_gemfile <<-G
        source "file://localhost#{gem_repo1}"
        gem "foo", :path => "#{lib_path("foo")}"
      G

      build_lib "foo", "1.0", :path => lib_path("foo") do |s|
        s.add_dependency "rack", "1.0"
      end

      lic :install, :env => { "DEBUG" => 1 }

      expect(out).to match(/re-resolving dependencies/)
      lockfile_should_be <<-G
        GEM
          remote: file://localhost#{gem_repo1}/
          specs:
            rack (1.0.0)

        PATH
          remote: #{lib_path("foo")}
          specs:
            foo (1.0)
              rack (= 1.0)

        PLATFORMS
          #{lockfile_platforms}

        DEPENDENCIES
          foo!

        LICD WITH
           #{Lic::VERSION}
      G
    end

    it "for a path gem with deps and no changes", :lic => "< 2" do
      build_lib "foo", "1.0", :path => lib_path("foo") do |s|
        s.add_dependency "rack", "1.0"
        s.add_development_dependency "net-ssh", "1.0"
      end

      install_gemfile <<-G
        source "file://localhost#{gem_repo1}"
        gem "foo", :path => "#{lib_path("foo")}"
      G

      lic :check, :env => { "DEBUG" => 1 }

      expect(out).to match(/using resolution from the lockfile/)
      lockfile_should_be <<-G
        PATH
          remote: #{lib_path("foo")}
          specs:
            foo (1.0)
              rack (= 1.0)

        GEM
          remote: file://localhost#{gem_repo1}/
          specs:
            rack (1.0.0)

        PLATFORMS
          ruby

        DEPENDENCIES
          foo!

        LICD WITH
           #{Lic::VERSION}
      G
    end

    it "for a path gem with deps and no changes", :lic => "2" do
      build_lib "foo", "1.0", :path => lib_path("foo") do |s|
        s.add_dependency "rack", "1.0"
        s.add_development_dependency "net-ssh", "1.0"
      end

      install_gemfile <<-G
        source "file://localhost#{gem_repo1}"
        gem "foo", :path => "#{lib_path("foo")}"
      G

      lic :check, :env => { "DEBUG" => 1 }

      expect(out).to match(/using resolution from the lockfile/)
      lockfile_should_be <<-G
        GEM
          remote: file://localhost#{gem_repo1}/
          specs:
            rack (1.0.0)

        PATH
          remote: #{lib_path("foo")}
          specs:
            foo (1.0)
              rack (= 1.0)

        PLATFORMS
          #{lockfile_platforms}

        DEPENDENCIES
          foo!

        LICD WITH
           #{Lic::VERSION}
      G
    end

    it "for a rubygems gem" do
      install_gemfile <<-G
        source "file://localhost#{gem_repo1}"
        gem "foo"
      G

      lic :check, :env => { "DEBUG" => 1 }

      expect(out).to match(/using resolution from the lockfile/)
      lockfile_should_be <<-G
        GEM
          remote: file://localhost#{gem_repo1}/
          specs:
            foo (1.0)

        PLATFORMS
          #{lockfile_platforms}

        DEPENDENCIES
          foo

        LICD WITH
           #{Lic::VERSION}
      G
    end
  end

  describe "initialize" do
    context "gem version promoter" do
      context "with lockfile" do
        before do
          install_gemfile <<-G
          source "file://#{gem_repo1}"
          gem "foo"
          G
        end

        it "should get a locked specs list when updating all" do
          definition = Lic::Definition.new(licd_app("Gemfile.lock"), [], Lic::SourceList.new, true)
          locked_specs = definition.gem_version_promoter.locked_specs
          expect(locked_specs.to_a.map(&:name)).to eq ["foo"]
          expect(definition.instance_variable_get("@locked_specs").empty?).to eq true
        end
      end

      context "without gemfile or lockfile" do
        it "should not attempt to parse empty lockfile contents" do
          definition = Lic::Definition.new(nil, [], mock_source_list, true)
          expect(definition.gem_version_promoter.locked_specs.to_a).to eq []
        end
      end

      context "eager unlock" do
        let(:source_list) do
          Lic::SourceList.new.tap do |source_list|
            source_list.global_rubygems_source = "file://#{gem_repo4}"
          end
        end

        before do
          gemfile <<-G
            source "file://#{gem_repo4}"
            gem 'isolated_owner'

            gem 'shared_owner_a'
            gem 'shared_owner_b'
          G

          lockfile <<-L
            GEM
              remote: file://#{gem_repo4}
              specs:
                isolated_dep (2.0.1)
                isolated_owner (1.0.1)
                  isolated_dep (~> 2.0)
                shared_dep (5.0.1)
                shared_owner_a (3.0.1)
                  shared_dep (~> 5.0)
                shared_owner_b (4.0.1)
                  shared_dep (~> 5.0)

            PLATFORMS
              ruby

            DEPENDENCIES
              shared_owner_a
              shared_owner_b
              isolated_owner

            LICD WITH
               1.13.0
          L
        end

        it "should not eagerly unlock shared dependency with lic install conservative updating behavior" do
          updated_deps_in_gemfile = [Lic::Dependency.new("isolated_owner", ">= 0"),
                                     Lic::Dependency.new("shared_owner_a", "3.0.2"),
                                     Lic::Dependency.new("shared_owner_b", ">= 0")]
          unlock_hash_for_lic_install = {}
          definition = Lic::Definition.new(
            licd_app("Gemfile.lock"),
            updated_deps_in_gemfile,
            source_list,
            unlock_hash_for_lic_install
          )
          locked = definition.send(:converge_locked_specs).map(&:name)
          expect(locked).to include "shared_dep"
        end

        it "should not eagerly unlock shared dependency with lic update conservative updating behavior" do
          updated_deps_in_gemfile = [Lic::Dependency.new("isolated_owner", ">= 0"),
                                     Lic::Dependency.new("shared_owner_a", ">= 0"),
                                     Lic::Dependency.new("shared_owner_b", ">= 0")]
          definition = Lic::Definition.new(
            licd_app("Gemfile.lock"),
            updated_deps_in_gemfile,
            source_list,
            :gems => ["shared_owner_a"], :lock_shared_dependencies => true
          )
          locked = definition.send(:converge_locked_specs).map(&:name)
          expect(locked).to eq %w[isolated_dep isolated_owner shared_dep shared_owner_b]
          expect(locked.include?("shared_dep")).to be_truthy
        end
      end
    end
  end

  describe "find_resolved_spec" do
    it "with no platform set in SpecSet" do
      ss = Lic::SpecSet.new([build_stub_spec("a", "1.0"), build_stub_spec("b", "1.0")])
      dfn = Lic::Definition.new(nil, [], mock_source_list, true)
      dfn.instance_variable_set("@specs", ss)
      found = dfn.find_resolved_spec(build_spec("a", "0.9", "ruby").first)
      expect(found.name).to eq "a"
      expect(found.version.to_s).to eq "1.0"
    end
  end

  describe "find_indexed_specs" do
    it "with no platform set in indexed specs" do
      index = Lic::Index.new
      %w[1.0.0 1.0.1 1.1.0].each {|v| index << build_stub_spec("foo", v) }

      dfn = Lic::Definition.new(nil, [], mock_source_list, true)
      dfn.instance_variable_set("@index", index)
      found = dfn.find_indexed_specs(build_spec("foo", "0.9", "ruby").first)
      expect(found.length).to eq 3
    end
  end

  def build_stub_spec(name, version)
    Lic::StubSpecification.new(name, version, nil, nil)
  end

  def mock_source_list
    Class.new do
      def all_sources
        []
      end

      def path_sources
        []
      end

      def rubygems_remotes
        []
      end

      def replace_sources!(arg)
        nil
      end
    end.new
  end
end
