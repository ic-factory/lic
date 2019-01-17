# frozen_string_literal: true

require "lic/shared_helpers"
Lic::SharedHelpers.major_deprecation 2,
  "The Lic task for Vlad"

# Vlad task for Lic.
#
# Add "require 'lic/vlad'" in your Vlad deploy.rb, and
# include the vlad:lic:install task in your vlad:deploy task.
require "lic/deployment"

include Rake::DSL if defined? Rake::DSL

namespace :vlad do
  Lic::Deployment.define_task(Rake::RemoteTask, :remote_task, :roles => :app)
end
