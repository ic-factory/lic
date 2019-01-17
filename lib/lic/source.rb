# frozen_string_literal: true

module Lic
  class Source
    autoload :Gemspec,  "lic/source/gemspec"
    autoload :Git,      "lic/source/git"
    autoload :Metadata, "lic/source/metadata"
    autoload :Path,     "lic/source/path"
    autoload :Rubygems, "lic/source/rubygems"

    attr_accessor :dependency_names

    def unmet_deps
      specs.unmet_dependency_names
    end

    def version_message(spec)
      message = "#{spec.name} #{spec.version}"
      message += " (#{spec.platform})" if spec.platform != Gem::Platform::RUBY && !spec.platform.nil?

      if Lic.locked_gems
        locked_spec = Lic.locked_gems.specs.find {|s| s.name == spec.name }
        locked_spec_version = locked_spec.version if locked_spec
        if locked_spec_version && spec.version != locked_spec_version
          message += Lic.ui.add_color(" (was #{locked_spec_version})", version_color(spec.version, locked_spec_version))
        end
      end

      message
    end

    def can_lock?(spec)
      spec.source == self
    end

    # it's possible that gems from one source depend on gems from some
    # other source, so now we download gemspecs and iterate over those
    # dependencies, looking for gems we don't have info on yet.
    def double_check_for(*); end

    def dependency_names_to_double_check
      specs.dependency_names
    end

    def include?(other)
      other == self
    end

    def inspect
      "#<#{self.class}:0x#{object_id} #{self}>"
    end

    def path?
      instance_of?(Lic::Source::Path)
    end

    def extension_cache_path(spec)
      return unless Lic.feature_flag.global_gem_cache?
      return unless source_slug = extension_cache_slug(spec)
      Lic.user_cache.join(
        "extensions", Gem::Platform.local.to_s, Lic.ruby_scope,
        source_slug, spec.full_name
      )
    end

  private

    def version_color(spec_version, locked_spec_version)
      if Gem::Version.correct?(spec_version) && Gem::Version.correct?(locked_spec_version)
        # display yellow if there appears to be a regression
        earlier_version?(spec_version, locked_spec_version) ? :yellow : :green
      else
        # default to green if the versions cannot be directly compared
        :green
      end
    end

    def earlier_version?(spec_version, locked_spec_version)
      Gem::Version.new(spec_version) < Gem::Version.new(locked_spec_version)
    end

    def print_using_message(message)
      if !message.include?("(was ") && Lic.feature_flag.suppress_install_using_messages?
        Lic.ui.debug message
      else
        Lic.ui.info message
      end
    end

    def extension_cache_slug(_)
      nil
    end
  end
end
