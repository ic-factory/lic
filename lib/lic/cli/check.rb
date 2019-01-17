# frozen_string_literal: true

module Lic
  class CLI::Check
    attr_reader :options

    def initialize(options)
      @options = options
    end

    def run
      Lic.settings.set_command_option_if_given :path, options[:path]

      begin
        definition = Lic.definition
        definition.validate_runtime!
        not_installed = definition.missing_specs
      rescue GemNotFound, VersionConflict
        Lic.ui.error "Lic can't satisfy your Gemfile's dependencies."
        Lic.ui.warn "Install missing gems with `lic install`."
        exit 1
      end

      if not_installed.any?
        Lic.ui.error "The following gems are missing"
        not_installed.each {|s| Lic.ui.error " * #{s.name} (#{s.version})" }
        Lic.ui.warn "Install missing gems with `lic install`"
        exit 1
      elsif !Lic.default_lockfile.file? && Lic.frozen_lic?
        Lic.ui.error "This lic has been frozen, but there is no #{Lic.default_lockfile.relative_path_from(SharedHelpers.pwd)} present"
        exit 1
      else
        Lic.load.lock(:preserve_unknown_sections => true) unless options[:"dry-run"]
        Lic.ui.info "The Gemfile's dependencies are satisfied"
      end
    end
  end
end
