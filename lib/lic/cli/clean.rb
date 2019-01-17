# frozen_string_literal: true

module Lic
  class CLI::Clean
    attr_reader :options

    def initialize(options)
      @options = options
    end

    def run
      require_path_or_force unless options[:"dry-run"]
      Lic.load.clean(options[:"dry-run"])
    end

  protected

    def require_path_or_force
      return unless Lic.use_system_gems? && !options[:force]
      raise InvalidOption, "Cleaning all the gems on your system is dangerous! " \
        "If you're sure you want to remove every system gem not in this " \
        "lic, run `lic clean --force`."
    end
  end
end
