# frozen_string_literal: true

require "lic/shared_helpers"
Lic::SharedHelpers.major_deprecation 2,
  "The Lic task for Capistrano. Please use http://github.com/capistrano/lic"

# Capistrano task for Lic.
#
# Add "require 'lic/capistrano'" in your Capistrano deploy.rb, and
# Lic will be activated after each new deployment.
require "lic/deployment"
require "capistrano/version"

if defined?(Capistrano::Version) && Gem::Version.new(Capistrano::Version).release >= Gem::Version.new("3.0")
  raise "For Capistrano 3.x integration, please use http://github.com/capistrano/lic"
end

Capistrano::Configuration.instance(:must_exist).load do
  before "deploy:finalize_update", "lic:install"
  Lic::Deployment.define_task(self, :task, :except => { :no_release => true })
  set :rake, lambda { "#{fetch(:lic_cmd, "lic")} exec rake" }
end
