# frozen_string_literal: true

module Lic
  class CLI::Show
    attr_reader :options, :gem_name, :latest_specs
    def initialize(options, gem_name)
      @options = options
      @gem_name = gem_name
      @verbose = options[:verbose] || options[:outdated]
      @latest_specs = fetch_latest_specs if @verbose
    end

    def run
      Lic.ui.silence do
        Lic.definition.validate_runtime!
        Lic.load.lock
      end

      if gem_name
        if gem_name == "lic"
          path = File.expand_path("../../../..", __FILE__)
        else
          spec = Lic::CLI::Common.select_spec(gem_name, :regex_match)
          return unless spec
          path = spec.full_gem_path
          unless File.directory?(path)
            Lic.ui.warn "The gem #{gem_name} has been deleted. It was installed at:"
          end
        end
        return Lic.ui.info(path)
      end

      if options[:paths]
        Lic.load.specs.sort_by(&:name).map do |s|
          Lic.ui.info s.full_gem_path
        end
      else
        Lic.ui.info "Gems included by the lic:"
        Lic.load.specs.sort_by(&:name).each do |s|
          desc = "  * #{s.name} (#{s.version}#{s.git_version})"
          if @verbose
            latest = latest_specs.find {|l| l.name == s.name }
            Lic.ui.info <<-END.gsub(/^ +/, "")
              #{desc}
              \tSummary:  #{s.summary || "No description available."}
              \tHomepage: #{s.homepage || "No website available."}
              \tStatus:   #{outdated?(s, latest) ? "Outdated - #{s.version} < #{latest.version}" : "Up to date"}
            END
          else
            Lic.ui.info desc
          end
        end
      end
    end

  private

    def fetch_latest_specs
      definition = Lic.definition(true)
      if options[:outdated]
        Lic.ui.info "Fetching remote specs for outdated check...\n\n"
        Lic.ui.silence { definition.resolve_remotely! }
      else
        definition.resolve_with_cache!
      end
      Lic.reset!
      definition.specs
    end

    def outdated?(current, latest)
      return false unless latest
      Gem::Version.new(current.version) < Gem::Version.new(latest.version)
    end
  end
end
