# frozen_string_literal: true

module Lic
  class CLI::Binstubs
    attr_reader :options, :gems
    def initialize(options, gems)
      @options = options
      @gems = gems
    end

    def run
      Lic.definition.validate_runtime!
      path_option = options["path"]
      path_option = nil if path_option && path_option.empty?
      Lic.settings.set_command_option :bin, path_option if options["path"]
      Lic.settings.set_command_option_if_given :shebang, options["shebang"]
      installer = Installer.new(Lic.root, Lic.definition)

      installer_opts = { :force => options[:force], :binstubs_cmd => true }

      if options[:all]
        raise InvalidOption, "Cannot specify --all with specific gems" unless gems.empty?
        @gems = Lic.definition.specs.map(&:name)
        installer_opts.delete(:binstubs_cmd)
      elsif gems.empty?
        Lic.ui.error "`lic binstubs` needs at least one gem to run."
        exit 1
      end

      gems.each do |gem_name|
        spec = Lic.definition.specs.find {|s| s.name == gem_name }
        unless spec
          raise GemNotFound, Lic::CLI::Common.gem_not_found_message(
            gem_name, Lic.definition.specs
          )
        end

        if options[:standalone]
          next Lic.ui.warn("Sorry, Lic can only be run via RubyGems.") if gem_name == "lic"
          Lic.settings.temporary(:path => (Lic.settings[:path] || Lic.root)) do
            installer.generate_standalone_lic_executable_stubs(spec)
          end
        else
          installer.generate_lic_executable_stubs(spec, installer_opts)
        end
      end
    end
  end
end
