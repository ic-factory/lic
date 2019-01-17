# frozen_string_literal: true

module Lic
  class CLI::List
    def initialize(options)
      @options = options
    end

    def run
      raise InvalidOption, "The `--only-group` and `--without-group` options cannot be used together" if @options["only-group"] && @options["without-group"]

      raise InvalidOption, "The `--name-only` and `--paths` options cannot be used together" if @options["name-only"] && @options[:paths]

      specs = if @options["only-group"] || @options["without-group"]
        filtered_specs_by_groups
      else
        Lic.load.specs
      end.reject {|s| s.name == "lic" }.sort_by(&:name)

      return Lic.ui.info "No gems in the Gemfile" if specs.empty?

      return specs.each {|s| Lic.ui.info s.name } if @options["name-only"]
      return specs.each {|s| Lic.ui.info s.full_gem_path } if @options["paths"]

      Lic.ui.info "Gems included by the lic:"

      specs.each {|s| Lic.ui.info "  * #{s.name} (#{s.version}#{s.git_version})" }

      Lic.ui.info "Use `lic info` to print more detailed information about a gem"
    end

  private

    def verify_group_exists(groups)
      raise InvalidOption, "`#{@options["without-group"]}` group could not be found." if @options["without-group"] && !groups.include?(@options["without-group"].to_sym)

      raise InvalidOption, "`#{@options["only-group"]}` group could not be found." if @options["only-group"] && !groups.include?(@options["only-group"].to_sym)
    end

    def filtered_specs_by_groups
      definition = Lic.definition
      groups = definition.groups

      verify_group_exists(groups)

      show_groups =
        if @options["without-group"]
          groups.reject {|g| g == @options["without-group"].to_sym }
        elsif @options["only-group"]
          groups.select {|g| g == @options["only-group"].to_sym }
        else
          groups
        end.map(&:to_sym)

      definition.specs_for(show_groups)
    end
  end
end
