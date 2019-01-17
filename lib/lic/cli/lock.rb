# frozen_string_literal: true

module Lic
  class CLI::Lock
    attr_reader :options

    def initialize(options)
      @options = options
    end

    def run
      unless Lic.default_gemfile
        Lic.ui.error "Unable to find a Gemfile to lock"
        exit 1
      end

      print = options[:print]
      ui = Lic.ui
      Lic.ui = UI::Silent.new if print

      Lic::Fetcher.disable_endpoint = options["full-index"]

      update = options[:update]
      if update.is_a?(Array) # unlocking specific gems
        Lic::CLI::Common.ensure_all_gems_in_lockfile!(update)
        update = { :gems => update, :lock_shared_dependencies => options[:conservative] }
      end
      definition = Lic.definition(update)

      Lic::CLI::Common.configure_gem_version_promoter(Lic.definition, options) if options[:update]

      options["remove-platform"].each do |platform|
        definition.remove_platform(platform)
      end

      options["add-platform"].each do |platform_string|
        platform = Gem::Platform.new(platform_string)
        if platform.to_s == "unknown"
          Lic.ui.warn "The platform `#{platform_string}` is unknown to RubyGems " \
            "and adding it will likely lead to resolution errors"
        end
        definition.add_platform(platform)
      end

      if definition.platforms.empty?
        raise InvalidOption, "Removing all platforms from the lic is not allowed"
      end

      definition.resolve_remotely! unless options[:local]

      if print
        puts definition.to_lock
      else
        file = options[:lockfile]
        file = file ? File.expand_path(file) : Lic.default_lockfile
        puts "Writing lockfile to #{file}"
        definition.lock(file)
      end

      Lic.ui = ui
    end
  end
end
