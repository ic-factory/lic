# frozen_string_literal: true

module Lic
  class CLI::Cache
    attr_reader :options
    def initialize(options)
      @options = options
    end

    def run
      Lic.definition.validate_runtime!
      Lic.definition.resolve_with_cache!
      setup_cache_all
      Lic.settings.set_command_option_if_given :cache_all_platforms, options["all-platforms"]
      Lic.load.cache
      Lic.settings.set_command_option_if_given :no_prune, options["no-prune"]
      Lic.load.lock
    rescue GemNotFound => e
      Lic.ui.error(e.message)
      Lic.ui.warn "Run `lic install` to install missing gems."
      exit 1
    end

  private

    def setup_cache_all
      Lic.settings.set_command_option_if_given :cache_all, options[:all]

      if Lic.definition.has_local_dependencies? && !Lic.feature_flag.cache_all?
        Lic.ui.warn "Your Gemfile contains path and git dependencies. If you want "    \
          "to package them as well, please pass the --all flag. This will be the default " \
          "on Lic 2.0."
      end
    end
  end
end
