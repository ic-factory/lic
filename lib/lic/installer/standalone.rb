# frozen_string_literal: true

module Lic
  class Standalone
    def initialize(groups, definition)
      @specs = groups.empty? ? definition.requested_specs : definition.specs_for(groups.map(&:to_sym))
    end

    def generate
      SharedHelpers.filesystem_access(lic_path) do |p|
        FileUtils.mkdir_p(p)
      end
      File.open File.join(lic_path, "setup.rb"), "w" do |file|
        file.puts "require 'rbconfig'"
        file.puts "# ruby 1.8.7 doesn't define RUBY_ENGINE"
        file.puts "ruby_engine = defined?(RUBY_ENGINE) ? RUBY_ENGINE : 'ruby'"
        file.puts "ruby_version = RbConfig::CONFIG[\"ruby_version\"]"
        file.puts "path = File.expand_path('..', __FILE__)"
        paths.each do |path|
          file.puts %($:.unshift "\#{path}/#{path}")
        end
      end
    end

  private

    def paths
      @specs.map do |spec|
        next if spec.name == "lic"
        Array(spec.require_paths).map do |path|
          gem_path(path, spec).sub(version_dir, '#{ruby_engine}/#{ruby_version}')
          # This is a static string intentionally. It's interpolated at a later time.
        end
      end.flatten
    end

    def version_dir
      "#{Lic::RubyVersion.system.engine}/#{RbConfig::CONFIG["ruby_version"]}"
    end

    def lic_path
      Lic.root.join(Lic.settings[:path], "lic")
    end

    def gem_path(path, spec)
      full_path = Pathname.new(path).absolute? ? path : File.join(spec.full_gem_path, path)
      Pathname.new(full_path).relative_path_from(Lic.root.join(lic_path)).to_s
    rescue TypeError
      error_message = "#{spec.name} #{spec.version} has an invalid gemspec"
      raise Gem::InvalidSpecificationException.new(error_message)
    end
  end
end
