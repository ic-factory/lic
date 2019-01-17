# frozen_string_literal: true

module Lic
  class GemInstaller
    attr_reader :spec, :standalone, :worker, :force, :installer

    def initialize(spec, installer, standalone = false, worker = 0, force = false)
      @spec = spec
      @installer = installer
      @standalone = standalone
      @worker = worker
      @force = force
    end

    def install_from_spec
      post_install_message = spec_settings ? install_with_settings : install
      Lic.ui.debug "#{worker}:  #{spec.name} (#{spec.version}) from #{spec.loaded_from}"
      generate_executable_stubs
      return true, post_install_message
    rescue Lic::InstallHookError, Lic::SecurityError, APIResponseMismatchError
      raise
    rescue Errno::ENOSPC
      return false, out_of_space_message
    rescue StandardError => e
      return false, specific_failure_message(e)
    end

  private

    def specific_failure_message(e)
      message = "#{e.class}: #{e.message}\n"
      message += "  " + e.backtrace.join("\n  ") + "\n\n" if Lic.ui.debug?
      message = message.lines.first + Lic.ui.add_color(message.lines.drop(1).join, :clear)
      message + Lic.ui.add_color(failure_message, :red)
    end

    def failure_message
      return install_error_message if spec.source.options["git"]
      "#{install_error_message}\n#{gem_install_message}"
    end

    def install_error_message
      "An error occurred while installing #{spec.name} (#{spec.version}), and Lic cannot continue."
    end

    def gem_install_message
      source = spec.source
      return unless source.respond_to?(:remotes)

      if source.remotes.size == 1
        "Make sure that `gem install #{spec.name} -v '#{spec.version}' --source '#{source.remotes.first}'` succeeds before bundling."
      else
        "Make sure that `gem install #{spec.name} -v '#{spec.version}'` succeeds before bundling."
      end
    end

    def spec_settings
      # Fetch the build settings, if there are any
      Lic.settings["build.#{spec.name}"]
    end

    def install
      spec.source.install(spec, :force => force, :ensure_builtin_gems_cached => standalone, :build_args => Array(spec_settings))
    end

    def install_with_settings
      # Build arguments are global, so this is mutexed
      Lic.rubygems.install_with_build_args([spec_settings]) { install }
    end

    def out_of_space_message
      "#{install_error_message}\nYour disk is out of space. Free some space to be able to install your lic."
    end

    def generate_executable_stubs
      return if Lic.feature_flag.forget_cli_options?
      return if Lic.settings[:inline]
      if Lic.settings[:bin] && standalone
        installer.generate_standalone_lic_executable_stubs(spec)
      elsif Lic.settings[:bin]
        installer.generate_lic_executable_stubs(spec, :force => true)
      end
    end
  end
end
