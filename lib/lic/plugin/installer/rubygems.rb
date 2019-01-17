# frozen_string_literal: true

module Lic
  module Plugin
    class Installer
      class Rubygems < Lic::Source::Rubygems
        def version_message(spec)
          "#{spec.name} #{spec.version}"
        end

      private

        def requires_sudo?
          false # Will change on implementation of project level plugins
        end

        def rubygems_dir
          Plugin.root
        end

        def cache_path
          Plugin.cache
        end
      end
    end
  end
end
