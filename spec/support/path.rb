# frozen_string_literal: true

require "pathname"

module Spec
  module Path
    def root
      @root ||= Pathname.new(ruby_core? ? "../../../.." : "../../..").expand_path(__FILE__)
    end

    def gemspec
      @gemspec ||= root.join(ruby_core? ? "lib/lic.gemspec" : "lic.gemspec")
    end

    def bindir
      @bindir ||= root.join(ruby_core? ? "libexec" : "exe")
    end

    def spec_dir
      @spec_dir ||= root.join(ruby_core? ? "spec/lic" : "spec")
    end

    def tmp(*path)
      root.join("tmp", *path)
    end

    def home(*path)
      tmp.join("home", *path)
    end

    def default_lic_path(*path)
      if Lic::VERSION.split(".").first.to_i < 2
        system_gem_path(*path)
      else
        licd_app(*[".lic", ENV.fetch("LIC_SPEC_RUBY_ENGINE", Gem.ruby_engine), Gem::ConfigMap[:ruby_version], *path].compact)
      end
    end

    def licd_app(*path)
      root = tmp.join("licd_app")
      FileUtils.mkdir_p(root)
      root.join(*path)
    end

    alias_method :licd_app1, :licd_app

    def licd_app2(*path)
      root = tmp.join("licd_app2")
      FileUtils.mkdir_p(root)
      root.join(*path)
    end

    def vendored_gems(path = nil)
      licd_app(*["vendor/lic", Gem.ruby_engine, Gem::ConfigMap[:ruby_version], path].compact)
    end

    def cached_gem(path)
      licd_app("vendor/cache/#{path}.gem")
    end

    def base_system_gems
      tmp.join("gems/base")
    end

    def gem_repo1(*args)
      tmp("gems/remote1", *args)
    end

    def gem_repo_missing(*args)
      tmp("gems/missing", *args)
    end

    def gem_repo2(*args)
      tmp("gems/remote2", *args)
    end

    def gem_repo3(*args)
      tmp("gems/remote3", *args)
    end

    def gem_repo4(*args)
      tmp("gems/remote4", *args)
    end

    def security_repo(*args)
      tmp("gems/security_repo", *args)
    end

    def system_gem_path(*path)
      tmp("gems/system", *path)
    end

    def system_lic_bin_path
      system_gem_path("bin/lic")
    end

    def lib_path(*args)
      tmp("libs", *args)
    end

    def lic_path
      root.join("lib")
    end

    def global_plugin_gem(*args)
      home ".lic", "plugin", "gems", *args
    end

    def local_plugin_gem(*args)
      licd_app ".lic", "plugin", "gems", *args
    end

    def tmpdir(*args)
      tmp "tmpdir", *args
    end

    def ruby_core?
      # avoid to wornings
      @ruby_core ||= nil

      if @ruby_core.nil?
        @ruby_core = true & (ENV["LIC_RUBY"] && ENV["LIC_GEM"])
      else
        @ruby_core
      end
    end

    extend self
  end
end
