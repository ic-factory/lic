# frozen_string_literal: true

module Lic
  class CLI::Update
    attr_reader :options, :gems
    def initialize(options, gems)
      @options = options
      @gems = gems
    end

    def run
      Lic.ui.level = "error" if options[:quiet]

      Plugin.gemfile_install(Lic.default_gemfile) if Lic.feature_flag.plugins?

      sources = Array(options[:source])
      groups  = Array(options[:group]).map(&:to_sym)

      full_update = gems.empty? && sources.empty? && groups.empty? && !options[:ruby] && !options[:lic]

      if full_update && !options[:all]
        if Lic.feature_flag.update_requires_all_flag?
          raise InvalidOption, "To update everything, pass the `--all` flag."
        end
        SharedHelpers.major_deprecation 2, "Pass --all to `lic update` to update everything"
      elsif !full_update && options[:all]
        raise InvalidOption, "Cannot specify --all along with specific options."
      end

      if full_update
        # We're doing a full update
        Lic.definition(true)
      else
        unless Lic.default_lockfile.exist?
          raise GemfileLockNotFound, "This Bundle hasn't been installed yet. " \
            "Run `lic install` to update and install the licd gems."
        end
        Lic::CLI::Common.ensure_all_gems_in_lockfile!(gems)

        if groups.any?
          deps = Lic.definition.dependencies.select {|d| (d.groups & groups).any? }
          gems.concat(deps.map(&:name))
        end

        Lic.definition(:gems => gems, :sources => sources, :ruby => options[:ruby],
                           :lock_shared_dependencies => options[:conservative],
                           :lic => options[:lic])
      end

      Lic::CLI::Common.configure_gem_version_promoter(Lic.definition, options)

      Lic::Fetcher.disable_endpoint = options["full-index"]

      opts = options.dup
      opts["update"] = true
      opts["local"] = options[:local]

      Lic.settings.set_command_option_if_given :jobs, opts["jobs"]

      Lic.definition.validate_runtime!
      installer = Installer.install Lic.root, Lic.definition, opts
      Lic.load.cache if Lic.app_cache.exist?

      if CLI::Common.clean_after_install?
        require "lic/cli/clean"
        Lic::CLI::Clean.new(options).run
      end

      if locked_gems = Lic.definition.locked_gems
        gems.each do |name|
          locked_version = locked_gems.specs.find {|s| s.name == name }
          locked_version &&= locked_version.version
          next unless locked_version
          new_version = Lic.definition.specs[name].first
          new_version &&= new_version.version
          if !new_version
            Lic.ui.warn "Lic attempted to update #{name} but it was removed from the lic"
          elsif new_version < locked_version
            Lic.ui.warn "Note: #{name} version regressed from #{locked_version} to #{new_version}"
          elsif new_version == locked_version
            Lic.ui.warn "Lic attempted to update #{name} but its version stayed the same"
          end
        end
      end

      Lic.ui.confirm "Bundle updated!"
      Lic::CLI::Common.output_without_groups_message
      Lic::CLI::Common.output_post_install_messages installer.post_install_messages
    end
  end
end
