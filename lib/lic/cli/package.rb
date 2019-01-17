# frozen_string_literal: true

module Lic
  class CLI::Package
    attr_reader :options

    def initialize(options)
      @options = options
    end

    def run
      Lic.ui.level = "error" if options[:quiet]
      Lic.settings.set_command_option_if_given :path, options[:path]
      Lic.settings.set_command_option_if_given :cache_all_platforms, options["all-platforms"]
      Lic.settings.set_command_option_if_given :cache_path, options["cache-path"]

      setup_cache_all
      install

      # TODO: move cache contents here now that all lics are locked
      custom_path = Lic.settings[:path] if options[:path]
      Lic.load.cache(custom_path)
    end

  private

    def install
      require "lic/cli/install"
      options = self.options.dup
      if Lic.settings[:cache_all_platforms]
        options["local"] = false
        options["update"] = true
      end
      Lic::CLI::Install.new(options).run
    end

    def setup_cache_all
      all = options.fetch(:all, Lic.feature_flag.cache_command_is_package? || nil)

      Lic.settings.set_command_option_if_given :cache_all, all

      if Lic.definition.has_local_dependencies? && !Lic.feature_flag.cache_all?
        Lic.ui.warn "Your Gemfile contains path and git dependencies. If you want "    \
          "to package them as well, please pass the --all flag. This will be the default " \
          "on Lic 2.0."
      end
    end
  end
end
