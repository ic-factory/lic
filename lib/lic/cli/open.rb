# frozen_string_literal: true

require "shellwords"

module Lic
  class CLI::Open
    attr_reader :options, :name
    def initialize(options, name)
      @options = options
      @name = name
    end

    def run
      editor = [ENV["LIC_EDITOR"], ENV["VISUAL"], ENV["EDITOR"]].find {|e| !e.nil? && !e.empty? }
      return Lic.ui.info("To open a licd gem, set $EDITOR or $LIC_EDITOR") unless editor
      return unless spec = Lic::CLI::Common.select_spec(name, :regex_match)
      path = spec.full_gem_path
      Dir.chdir(path) do
        command = Shellwords.split(editor) + [path]
        Lic.with_original_env do
          system(*command)
        end || Lic.ui.info("Could not run '#{command.join(" ")}'")
      end
    end
  end
end
