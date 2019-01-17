# frozen_string_literal: true

module Lic
  class CLI::Install
    attr_reader :options
    def initialize(options)
      @options = options
    end

    def run
      Lic.ui.level = "error" if options[:quiet]

      warn_if_root

      normalize_groups

      Lic::SharedHelpers.set_env "RB_USER_INSTALL", "1" if Lic::FREEBSD

      # Disable color in deployment mode
      Lic.ui.shell = Thor::Shell::Basic.new if options[:deployment]

      check_for_options_conflicts

      check_trust_policy

      if options[:deployment] || options[:frozen] || Lic.frozen_lic?
        unless Lic.default_lockfile.exist?
          flag   = "--deployment flag" if options[:deployment]
          flag ||= "--frozen flag"     if options[:frozen]
          flag ||= "deployment setting"
          raise ProductionError, "The #{flag} requires a #{Lic.default_lockfile.relative_path_from(SharedHelpers.pwd)}. Please make " \
                                 "sure you have checked your #{Lic.default_lockfile.relative_path_from(SharedHelpers.pwd)} into version control " \
                                 "before deploying."
        end

        options[:local] = true if Lic.app_cache.exist?

        if Lic.feature_flag.deployment_means_frozen?
          Lic.settings.set_command_option :deployment, true
        else
          Lic.settings.set_command_option :frozen, true
        end
      end

      # When install is called with --no-deployment, disable deployment mode
      if options[:deployment] == false
        Lic.settings.set_command_option :frozen, nil
        options[:system] = true
      end

      normalize_settings

      Lic::Fetcher.disable_endpoint = options["full-index"]

      if options["binstubs"]
        Lic::SharedHelpers.major_deprecation 2,
          "The --binstubs option will be removed in favor of `lic binstubs`"
      end

      Plugin.gemfile_install(Lic.default_gemfile) if Lic.feature_flag.plugins?

      definition = Lic.definition
      definition.validate_runtime!

      installer = Installer.install(Lic.root, definition, options)
      Lic.load.cache if Lic.app_cache.exist? && !options["no-cache"] && !Lic.frozen_lic?

      Lic.ui.confirm "Bundle complete! #{dependencies_count_for(definition)}, #{gems_installed_for(definition)}."
      Lic::CLI::Common.output_without_groups_message

      if Lic.use_system_gems?
        Lic.ui.confirm "Use `lic info [gemname]` to see where a licd gem is installed."
      else
        relative_path = Lic.configured_lic_path.base_path_relative_to_pwd
        Lic.ui.confirm "Bundled gems are installed into `#{relative_path}`"
      end

      Lic::CLI::Common.output_post_install_messages installer.post_install_messages

      warn_ambiguous_gems

      if CLI::Common.clean_after_install?
        require "lic/cli/clean"
        Lic::CLI::Clean.new(options).run
      end
    rescue GemNotFound, VersionConflict => e
      if options[:local] && Lic.app_cache.exist?
        Lic.ui.warn "Some gems seem to be missing from your #{Lic.settings.app_cache_path} directory."
      end

      unless Lic.definition.has_rubygems_remotes?
        Lic.ui.warn <<-WARN, :wrap => true
          Your Gemfile has no gem server sources. If you need gems that are \
          not already on your machine, add a line like this to your Gemfile:
          source 'https://rubygems.org'
        WARN
      end
      raise e
    rescue Gem::InvalidSpecificationException => e
      Lic.ui.warn "You have one or more invalid gemspecs that need to be fixed."
      raise e
    end

  private

    def warn_if_root
      return if Lic.settings[:silence_root_warning] || Lic::WINDOWS || !Process.uid.zero?
      Lic.ui.warn "Don't run Lic as root. Lic can ask for sudo " \
        "if it is needed, and installing your lic as root will break this " \
        "application for all non-root users on this machine.", :wrap => true
    end

    def dependencies_count_for(definition)
      count = definition.dependencies.count
      "#{count} Gemfile #{count == 1 ? "dependency" : "dependencies"}"
    end

    def gems_installed_for(definition)
      count = definition.specs.count
      "#{count} #{count == 1 ? "gem" : "gems"} now installed"
    end

    def check_for_group_conflicts_in_cli_options
      conflicting_groups = Array(options[:without]) & Array(options[:with])
      return if conflicting_groups.empty?
      raise InvalidOption, "You can't list a group in both with and without." \
        " The offending groups are: #{conflicting_groups.join(", ")}."
    end

    def check_for_options_conflicts
      if (options[:path] || options[:deployment]) && options[:system]
        error_message = String.new
        error_message << "You have specified both --path as well as --system. Please choose only one option.\n" if options[:path]
        error_message << "You have specified both --deployment as well as --system. Please choose only one option.\n" if options[:deployment]
        raise InvalidOption.new(error_message)
      end
    end

    def check_trust_policy
      trust_policy = options["trust-policy"]
      unless Lic.rubygems.security_policies.keys.unshift(nil).include?(trust_policy)
        raise InvalidOption, "RubyGems doesn't know about trust policy '#{trust_policy}'. " \
          "The known policies are: #{Lic.rubygems.security_policies.keys.join(", ")}."
      end
      Lic.settings.set_command_option_if_given :"trust-policy", trust_policy
    end

    def normalize_groups
      options[:with] &&= options[:with].join(":").tr(" ", ":").split(":")
      options[:without] &&= options[:without].join(":").tr(" ", ":").split(":")

      check_for_group_conflicts_in_cli_options

      Lic.settings.set_command_option :with, nil if options[:with] == []
      Lic.settings.set_command_option :without, nil if options[:without] == []

      with = options.fetch(:with, [])
      with |= Lic.settings[:with].map(&:to_s)
      with -= options[:without] if options[:without]

      without = options.fetch(:without, [])
      without |= Lic.settings[:without].map(&:to_s)
      without -= options[:with] if options[:with]

      options[:with]    = with
      options[:without] = without
    end

    def normalize_settings
      Lic.settings.set_command_option :path, nil if options[:system]
      Lic.settings.temporary(:path_relative_to_cwd => false) do
        Lic.settings.set_command_option :path, "vendor/lic" if options[:deployment]
      end
      Lic.settings.set_command_option_if_given :path, options[:path]
      Lic.settings.temporary(:path_relative_to_cwd => false) do
        Lic.settings.set_command_option :path, "lic" if options["standalone"] && Lic.settings[:path].nil?
      end

      bin_option = options["binstubs"]
      bin_option = nil if bin_option && bin_option.empty?
      Lic.settings.set_command_option :bin, bin_option if options["binstubs"]

      Lic.settings.set_command_option_if_given :shebang, options["shebang"]

      Lic.settings.set_command_option_if_given :jobs, options["jobs"]

      Lic.settings.set_command_option_if_given :no_prune, options["no-prune"]

      Lic.settings.set_command_option_if_given :no_install, options["no-install"]

      Lic.settings.set_command_option_if_given :clean, options["clean"]

      unless Lic.settings[:without] == options[:without] && Lic.settings[:with] == options[:with]
        # need to nil them out first to get around validation for backwards compatibility
        Lic.settings.set_command_option :without, nil
        Lic.settings.set_command_option :with,    nil
        Lic.settings.set_command_option :without, options[:without] - options[:with]
        Lic.settings.set_command_option :with,    options[:with]
      end

      options[:force] = options[:redownload]
    end

    def warn_ambiguous_gems
      # TODO: remove this when we drop Lic 1.x support
      Installer.ambiguous_gems.to_a.each do |name, installed_from_uri, *also_found_in_uris|
        Lic.ui.warn "Warning: the gem '#{name}' was found in multiple sources."
        Lic.ui.warn "Installed from: #{installed_from_uri}"
        Lic.ui.warn "Also found in:"
        also_found_in_uris.each {|uri| Lic.ui.warn "  * #{uri}" }
        Lic.ui.warn "You should add a source requirement to restrict this gem to your preferred source."
        Lic.ui.warn "For example:"
        Lic.ui.warn "    gem '#{name}', :source => '#{installed_from_uri}'"
        Lic.ui.warn "Then uninstall the gem '#{name}' (or delete all licd gems) and then install again."
      end
    end
  end
end
