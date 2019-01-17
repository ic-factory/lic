# frozen_string_literal: true

require "lic/shared_helpers"
Lic::SharedHelpers.major_deprecation 2, "Lic no longer integrates with " \
  "Capistrano, but Capistrano provides its own integration with " \
  "Lic via the capistrano-lic gem. Use it instead."

module Lic
  class Deployment
    def self.define_task(context, task_method = :task, opts = {})
      if defined?(Capistrano) && context.is_a?(Capistrano::Configuration)
        context_name = "capistrano"
        role_default = "{:except => {:no_release => true}}"
        error_type = ::Capistrano::CommandError
      else
        context_name = "vlad"
        role_default = "[:app]"
        error_type = ::Rake::CommandFailedError
      end

      roles = context.fetch(:lic_roles, false)
      opts[:roles] = roles if roles

      context.send :namespace, :lic do
        send :desc, <<-DESC
          Install the current Lic environment. By default, gems will be \
          installed to the shared/lic path. Gems in the development and \
          test group will not be installed. The install command is executed \
          with the --deployment and --quiet flags. If the lic cmd cannot \
          be found then you can override the lic_cmd variable to specify \
          which one it should use. The base path to the app is fetched from \
          the :latest_release variable. Set it for custom deploy layouts.

          You can override any of these defaults by setting the variables shown below.

          N.B. lic_roles must be defined before you require 'lic/#{context_name}' \
          in your deploy.rb file.

            set :lic_gemfile,  "Gemfile"
            set :lic_dir,      File.join(fetch(:shared_path), 'lic')
            set :lic_flags,    "--deployment --quiet"
            set :lic_without,  [:development, :test]
            set :lic_with,     [:mysql]
            set :lic_cmd,      "lic" # e.g. "/opt/ruby/bin/lic"
            set :lic_roles,    #{role_default} # e.g. [:app, :batch]
        DESC
        send task_method, :install, opts do
          lic_cmd     = context.fetch(:lic_cmd, "lic")
          lic_flags   = context.fetch(:lic_flags, "--deployment --quiet")
          lic_dir     = context.fetch(:lic_dir, File.join(context.fetch(:shared_path), "lic"))
          lic_gemfile = context.fetch(:lic_gemfile, "Gemfile")
          lic_without = [*context.fetch(:lic_without, [:development, :test])].compact
          lic_with    = [*context.fetch(:lic_with, [])].compact
          app_path = context.fetch(:latest_release)
          if app_path.to_s.empty?
            raise error_type.new("Cannot detect current release path - make sure you have deployed at least once.")
          end
          args = ["--gemfile #{File.join(app_path, lic_gemfile)}"]
          args << "--path #{lic_dir}" unless lic_dir.to_s.empty?
          args << lic_flags.to_s
          args << "--without #{lic_without.join(" ")}" unless lic_without.empty?
          args << "--with #{lic_with.join(" ")}" unless lic_with.empty?

          run "cd #{app_path} && #{lic_cmd} install #{args.join(" ")}"
        end
      end
    end
  end
end
