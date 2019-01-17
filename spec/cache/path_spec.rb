# frozen_string_literal: true

%w[cache package].each do |cmd|
  RSpec.describe "lic #{cmd} with path" do
    it "is no-op when the path is within the lic" do
      build_lib "foo", :path => licd_app("lib/foo")

      install_gemfile <<-G
        gem "foo", :path => '#{licd_app("lib/foo")}'
      G

      lic cmd, forgotten_command_line_options([:all, :cache_all] => true)
      expect(licd_app("vendor/cache/foo-1.0")).not_to exist
      expect(the_lic).to include_gems "foo 1.0"
    end

    it "copies when the path is outside the lic " do
      build_lib "foo"

      install_gemfile <<-G
        gem "foo", :path => '#{lib_path("foo-1.0")}'
      G

      lic cmd, forgotten_command_line_options([:all, :cache_all] => true)
      expect(licd_app("vendor/cache/foo-1.0")).to exist
      expect(licd_app("vendor/cache/foo-1.0/.liccache")).to be_file

      FileUtils.rm_rf lib_path("foo-1.0")
      expect(the_lic).to include_gems "foo 1.0"
    end

    it "copies when the path is outside the lic and the paths intersect" do
      libname = File.basename(Dir.pwd) + "_gem"
      libpath = File.join(File.dirname(Dir.pwd), libname)

      build_lib libname, :path => libpath

      install_gemfile <<-G
        gem "#{libname}", :path => '#{libpath}'
      G

      lic cmd, forgotten_command_line_options([:all, :cache_all] => true)
      expect(licd_app("vendor/cache/#{libname}")).to exist
      expect(licd_app("vendor/cache/#{libname}/.liccache")).to be_file

      FileUtils.rm_rf libpath
      expect(the_lic).to include_gems "#{libname} 1.0"
    end

    it "updates the path on each cache" do
      build_lib "foo"

      install_gemfile <<-G
        gem "foo", :path => '#{lib_path("foo-1.0")}'
      G

      lic cmd, forgotten_command_line_options([:all, :cache_all] => true)

      build_lib "foo" do |s|
        s.write "lib/foo.rb", "puts :CACHE"
      end

      lic cmd, forgotten_command_line_options([:all, :cache_all] => true)

      expect(licd_app("vendor/cache/foo-1.0")).to exist
      FileUtils.rm_rf lib_path("foo-1.0")

      run "require 'foo'"
      expect(out).to eq("CACHE")
    end

    it "removes stale entries cache" do
      build_lib "foo"

      install_gemfile <<-G
        gem "foo", :path => '#{lib_path("foo-1.0")}'
      G

      lic cmd, forgotten_command_line_options([:all, :cache_all] => true)

      install_gemfile <<-G
        gem "bar", :path => '#{lib_path("bar-1.0")}'
      G

      lic cmd, forgotten_command_line_options([:all, :cache_all] => true)
      expect(licd_app("vendor/cache/bar-1.0")).not_to exist
    end

    it "raises a warning without --all", :lic => "< 2" do
      build_lib "foo"

      install_gemfile <<-G
        gem "foo", :path => '#{lib_path("foo-1.0")}'
      G

      lic cmd
      expect(out).to match(/please pass the \-\-all flag/)
      expect(licd_app("vendor/cache/foo-1.0")).not_to exist
    end

    it "stores the given flag" do
      build_lib "foo"

      install_gemfile <<-G
        gem "foo", :path => '#{lib_path("foo-1.0")}'
      G

      lic cmd, forgotten_command_line_options([:all, :cache_all] => true)
      build_lib "bar"

      install_gemfile <<-G
        gem "foo", :path => '#{lib_path("foo-1.0")}'
        gem "bar", :path => '#{lib_path("bar-1.0")}'
      G

      lic cmd
      expect(licd_app("vendor/cache/bar-1.0")).to exist
    end

    it "can rewind chosen configuration" do
      build_lib "foo"

      install_gemfile <<-G
        gem "foo", :path => '#{lib_path("foo-1.0")}'
      G

      lic cmd, forgotten_command_line_options([:all, :cache_all] => true)
      build_lib "baz"

      gemfile <<-G
        gem "foo", :path => '#{lib_path("foo-1.0")}'
        gem "baz", :path => '#{lib_path("baz-1.0")}'
      G

      lic "#{cmd} --no-all"
      expect(licd_app("vendor/cache/baz-1.0")).not_to exist
    end
  end
end
