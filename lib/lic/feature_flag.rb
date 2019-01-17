# frozen_string_literal: true

module Lic
  class FeatureFlag
    def self.settings_flag(flag, &default)
      unless Lic::Settings::BOOL_KEYS.include?(flag.to_s)
        raise "Cannot use `#{flag}` as a settings feature flag since it isn't a bool key"
      end

      settings_method("#{flag}?", flag, &default)
    end
    private_class_method :settings_flag

    def self.settings_option(key, &default)
      settings_method(key, key, &default)
    end
    private_class_method :settings_option

    def self.settings_method(name, key, &default)
      define_method(name) do
        value = Lic.settings[key]
        value = instance_eval(&default) if value.nil? && !default.nil?
        value
      end
    end
    private_class_method :settings_method

    (1..10).each {|v| define_method("lic_#{v}_mode?") { major_version >= v } }

    settings_flag(:allow_lic_dependency_conflicts) { lic_2_mode? }
    settings_flag(:allow_offline_install) { lic_2_mode? }
    settings_flag(:auto_clean_without_path) { lic_2_mode? }
    settings_flag(:auto_config_jobs) { lic_2_mode? }
    settings_flag(:cache_all) { lic_2_mode? }
    settings_flag(:cache_command_is_package) { lic_2_mode? }
    settings_flag(:console_command) { !lic_2_mode? }
    settings_flag(:default_install_uses_path) { lic_2_mode? }
    settings_flag(:deployment_means_frozen) { lic_2_mode? }
    settings_flag(:disable_multisource) { lic_2_mode? }
    settings_flag(:error_on_stderr) { lic_2_mode? }
    settings_flag(:forget_cli_options) { lic_2_mode? }
    settings_flag(:global_path_appends_ruby_scope) { lic_2_mode? }
    settings_flag(:global_gem_cache) { lic_2_mode? }
    settings_flag(:init_gems_rb) { lic_2_mode? }
    settings_flag(:list_command) { lic_2_mode? }
    settings_flag(:lockfile_uses_separate_rubygems_sources) { lic_2_mode? }
    settings_flag(:only_update_to_newer_versions) { lic_2_mode? }
    settings_flag(:path_relative_to_cwd) { lic_2_mode? }
    settings_flag(:plugins) { @lic_version >= Gem::Version.new("1.14") }
    settings_flag(:prefer_gems_rb) { lic_2_mode? }
    settings_flag(:print_only_version_number) { lic_2_mode? }
    settings_flag(:setup_makes_kernel_gem_public) { !lic_2_mode? }
    settings_flag(:skip_default_git_sources) { lic_2_mode? }
    settings_flag(:specific_platform) { lic_2_mode? }
    settings_flag(:suppress_install_using_messages) { lic_2_mode? }
    settings_flag(:unlock_source_unlocks_spec) { !lic_2_mode? }
    settings_flag(:update_requires_all_flag) { lic_2_mode? }
    settings_flag(:use_gem_version_promoter_for_major_updates) { lic_2_mode? }
    settings_flag(:viz_command) { !lic_2_mode? }

    settings_option(:default_cli_command) { lic_2_mode? ? :cli_help : :install }

    settings_method(:github_https?, "github.https") { lic_2_mode? }

    def initialize(lic_version)
      @lic_version = Gem::Version.create(lic_version)
    end

    def major_version
      @lic_version.segments.first
    end
    private :major_version
  end
end
