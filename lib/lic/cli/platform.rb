# frozen_string_literal: true

module Lic
  class CLI::Platform
    attr_reader :options
    def initialize(options)
      @options = options
    end

    def run
      platforms, ruby_version = Lic.ui.silence do
        locked_ruby_version = Lic.locked_gems && Lic.locked_gems.ruby_version
        gemfile_ruby_version = Lic.definition.ruby_version && Lic.definition.ruby_version.single_version_string
        [Lic.definition.platforms.map {|p| "* #{p}" },
         locked_ruby_version || gemfile_ruby_version]
      end
      output = []

      if options[:ruby]
        if ruby_version
          output << ruby_version
        else
          output << "No ruby version specified"
        end
      else
        output << "Your platform is: #{RUBY_PLATFORM}"
        output << "Your app has gems that work on these platforms:\n#{platforms.join("\n")}"

        if ruby_version
          output << "Your Gemfile specifies a Ruby version requirement:\n* #{ruby_version}"

          begin
            Lic.definition.validate_runtime!
            output << "Your current platform satisfies the Ruby version requirement."
          rescue RubyVersionMismatch => e
            output << e.message
          end
        else
          output << "Your Gemfile does not specify a Ruby version requirement."
        end
      end

      Lic.ui.info output.join("\n\n")
    end
  end
end
