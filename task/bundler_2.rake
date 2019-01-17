# frozen_string_literal: true

namespace :lic_2 do
  task :install do
    ENV["LIC_SPEC_SUB_VERSION"] = "2.0.0.dev"
    Rake::Task["override_version"].invoke
    Rake::Task["install"].invoke
    sh("git", "checkout", "--", "lib/lic/version.rb")
  end
end
