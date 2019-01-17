# frozen_string_literal: true

RSpec.describe "global gem caching" do
  before { lic! "config global_gem_cache true" }

  describe "using the cross-application user cache" do
    let(:source)  { "http://localgemserver.test" }
    let(:source2) { "http://gemserver.example.org" }

    def source_global_cache(*segments)
      home(".lic", "cache", "gems", "localgemserver.test.80.dd34752a738ee965a2a4298dc16db6c5", *segments)
    end

    def source2_global_cache(*segments)
      home(".lic", "cache", "gems", "gemserver.example.org.80.1ae1663619ffe0a3c9d97712f44c705b", *segments)
    end

    it "caches gems into the global cache on download" do
      install_gemfile! <<-G, :artifice => "compact_index"
        source "#{source}"
        gem "rack"
      G

      expect(the_lic).to include_gems "rack 1.0.0"
      expect(source_global_cache("rack-1.0.0.gem")).to exist
    end

    it "uses globally cached gems if they exist" do
      source_global_cache.mkpath
      FileUtils.cp(gem_repo1("gems/rack-1.0.0.gem"), source_global_cache("rack-1.0.0.gem"))

      install_gemfile! <<-G, :artifice => "compact_index_no_gem"
        source "#{source}"
        gem "rack"
      G

      expect(the_lic).to include_gems "rack 1.0.0"
    end

    describe "when the same gem from different sources is installed" do
      it "should use the appropriate one from the global cache" do
        install_gemfile! <<-G, :artifice => "compact_index"
          source "#{source}"
          gem "rack"
        G

        FileUtils.rm_r(default_lic_path)
        expect(the_lic).not_to include_gems "rack 1.0.0"
        expect(source_global_cache("rack-1.0.0.gem")).to exist
        # rack 1.0.0 is not installed and it is in the global cache

        install_gemfile! <<-G, :artifice => "compact_index"
          source "#{source2}"
          gem "rack", "0.9.1"
        G

        FileUtils.rm_r(default_lic_path)
        expect(the_lic).not_to include_gems "rack 0.9.1"
        expect(source2_global_cache("rack-0.9.1.gem")).to exist
        # rack 0.9.1 is not installed and it is in the global cache

        gemfile <<-G
          source "#{source}"
          gem "rack", "1.0.0"
        G

        lic! :install, :artifice => "compact_index_no_gem"
        # rack 1.0.0 is installed and rack 0.9.1 is not
        expect(the_lic).to include_gems "rack 1.0.0"
        expect(the_lic).not_to include_gems "rack 0.9.1"
        FileUtils.rm_r(default_lic_path)

        gemfile <<-G
          source "#{source2}"
          gem "rack", "0.9.1"
        G

        lic! :install, :artifice => "compact_index_no_gem"
        # rack 0.9.1 is installed and rack 1.0.0 is not
        expect(the_lic).to include_gems "rack 0.9.1"
        expect(the_lic).not_to include_gems "rack 1.0.0"
      end

      it "should not install if the wrong source is provided" do
        gemfile <<-G
          source "#{source}"
          gem "rack"
        G

        lic! :install, :artifice => "compact_index"
        FileUtils.rm_r(default_lic_path)
        expect(the_lic).not_to include_gems "rack 1.0.0"
        expect(source_global_cache("rack-1.0.0.gem")).to exist
        # rack 1.0.0 is not installed and it is in the global cache

        gemfile <<-G
          source "#{source2}"
          gem "rack", "0.9.1"
        G

        lic! :install, :artifice => "compact_index"
        FileUtils.rm_r(default_lic_path)
        expect(the_lic).not_to include_gems "rack 0.9.1"
        expect(source2_global_cache("rack-0.9.1.gem")).to exist
        # rack 0.9.1 is not installed and it is in the global cache

        gemfile <<-G
          source "#{source2}"
          gem "rack", "1.0.0"
        G

        expect(source_global_cache("rack-1.0.0.gem")).to exist
        expect(source2_global_cache("rack-0.9.1.gem")).to exist
        lic :install, :artifice => "compact_index_no_gem"
        expect(out).to include("Internal Server Error 500")
        # rack 1.0.0 is not installed and rack 0.9.1 is not
        expect(the_lic).not_to include_gems "rack 1.0.0"
        expect(the_lic).not_to include_gems "rack 0.9.1"

        gemfile <<-G
          source "#{source}"
          gem "rack", "0.9.1"
        G

        expect(source_global_cache("rack-1.0.0.gem")).to exist
        expect(source2_global_cache("rack-0.9.1.gem")).to exist
        lic :install, :artifice => "compact_index_no_gem"
        expect(out).to include("Internal Server Error 500")
        # rack 0.9.1 is not installed and rack 1.0.0 is not
        expect(the_lic).not_to include_gems "rack 0.9.1"
        expect(the_lic).not_to include_gems "rack 1.0.0"
      end
    end

    describe "when installing gems from a different directory" do
      it "uses the global cache as a source" do
        install_gemfile! <<-G, :artifice => "compact_index"
          source "#{source}"
          gem "rack"
          gem "activesupport"
        G

        # Both gems are installed and in the global cache
        expect(the_lic).to include_gems "rack 1.0.0"
        expect(the_lic).to include_gems "activesupport 2.3.5"
        expect(source_global_cache("rack-1.0.0.gem")).to exist
        expect(source_global_cache("activesupport-2.3.5.gem")).to exist
        FileUtils.rm_r(default_lic_path)
        # Both gems are now only in the global cache
        expect(the_lic).not_to include_gems "rack 1.0.0"
        expect(the_lic).not_to include_gems "activesupport 2.3.5"

        install_gemfile! <<-G, :artifice => "compact_index_no_gem"
          source "#{source}"
          gem "rack"
        G

        # rack is installed and both are in the global cache
        expect(the_lic).to include_gems "rack 1.0.0"
        expect(the_lic).not_to include_gems "activesupport 2.3.5"
        expect(source_global_cache("rack-1.0.0.gem")).to exist
        expect(source_global_cache("activesupport-2.3.5.gem")).to exist

        Dir.chdir licd_app2 do
          create_file licd_app2("gems.rb"), <<-G
            source "#{source}"
            gem "activesupport"
          G

          # Neither gem is installed and both are in the global cache
          expect(the_lic).not_to include_gems "rack 1.0.0"
          expect(the_lic).not_to include_gems "activesupport 2.3.5"
          expect(source_global_cache("rack-1.0.0.gem")).to exist
          expect(source_global_cache("activesupport-2.3.5.gem")).to exist

          # Install using the global cache instead of by downloading the .gem
          # from the server
          lic! :install, :artifice => "compact_index_no_gem"

          # activesupport is installed and both are in the global cache
          expect(the_lic).not_to include_gems "rack 1.0.0"
          expect(the_lic).to include_gems "activesupport 2.3.5"
          expect(source_global_cache("rack-1.0.0.gem")).to exist
          expect(source_global_cache("activesupport-2.3.5.gem")).to exist
        end
      end
    end
  end

  describe "extension caching", :ruby_repo, :rubygems => "2.2" do
    it "works" do
      build_git "very_simple_git_binary", &:add_c_extension
      build_lib "very_simple_path_binary", &:add_c_extension
      revision = revision_for(lib_path("very_simple_git_binary-1.0"))[0, 12]

      install_gemfile! <<-G
        source "file:#{gem_repo1}"

        gem "very_simple_binary"
        gem "very_simple_git_binary", :git => "#{lib_path("very_simple_git_binary-1.0")}"
        gem "very_simple_path_binary", :path => "#{lib_path("very_simple_path_binary-1.0")}"
      G

      gem_binary_cache = home(".lic", "cache", "extensions", specific_local_platform.to_s, Lic.ruby_scope,
        Digest(:MD5).hexdigest("#{gem_repo1}/"), "very_simple_binary-1.0")
      git_binary_cache = home(".lic", "cache", "extensions", specific_local_platform.to_s, Lic.ruby_scope,
        "very_simple_git_binary-1.0-#{revision}", "very_simple_git_binary-1.0")

      cached_extensions = Pathname.glob(home(".lic", "cache", "extensions", "*", "*", "*", "*", "*")).sort
      expect(cached_extensions).to eq [gem_binary_cache, git_binary_cache].sort

      run! <<-R
        require 'very_simple_binary_c'; puts ::VERY_SIMPLE_BINARY_IN_C
        require 'very_simple_git_binary_c'; puts ::VERY_SIMPLE_GIT_BINARY_IN_C
      R
      expect(out).to eq "VERY_SIMPLE_BINARY_IN_C\nVERY_SIMPLE_GIT_BINARY_IN_C"

      FileUtils.rm Dir[home(".lic", "cache", "extensions", "**", "*binary_c*")]

      gem_binary_cache.join("very_simple_binary_c.rb").open("w") {|f| f << "puts File.basename(__FILE__)" }
      git_binary_cache.join("very_simple_git_binary_c.rb").open("w") {|f| f << "puts File.basename(__FILE__)" }

      lic! "config --local path different_path"
      lic! :install

      expect(Dir[home(".lic", "cache", "extensions", "**", "*binary_c*")]).to all(end_with(".rb"))

      run! <<-R
        require 'very_simple_binary_c'
        require 'very_simple_git_binary_c'
      R
      expect(out).to eq "very_simple_binary_c.rb\nvery_simple_git_binary_c.rb"
    end
  end
end
