# frozen_string_literal: true

module Lic
  module Plugin
    class Installer
      class Git < Lic::Source::Git
        def cache_path
          @cache_path ||= begin
            git_scope = "#{base_name}-#{uri_hash}"

            Plugin.cache.join("lic", "git", git_scope)
          end
        end

        def install_path
          @install_path ||= begin
            git_scope = "#{base_name}-#{shortref_for_path(revision)}"

            Plugin.root.join("lic", "gems", git_scope)
          end
        end

        def version_message(spec)
          "#{spec.name} #{spec.version}"
        end

        def root
          Plugin.root
        end

        def generate_bin(spec, disable_extensions = false)
          # Need to find a way without code duplication
          # For now, we can ignore this
        end
      end
    end
  end
end