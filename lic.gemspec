# coding: utf-8
# frozen_string_literal: true

begin
  require File.expand_path("../lib/lic/version", __FILE__)
rescue LoadError
  # for Ruby core repository
  require File.expand_path("../lic/version", __FILE__)
end

Gem::Specification.new do |s|
  s.name        = "lic"
  s.version     = Lic::VERSION
  s.license     = "MIT"
  s.authors     = ["Torben Fox Jacobsen"]
  s.email       = ["lic@ic-factory.com"]
  s.homepage    = "https://github.com/ic-factory/lic"
  s.summary     = "The best way to manage your IC projects's libraries"
  s.description = "Lic manages an IC project's dependencies through its entire life, across many machines, systematically and repeatably"

  if s.respond_to?(:metadata=)
    s.metadata = {
      "bug_tracker_uri" => "https://github.com/ic-factory/lic/issues",
      "changelog_uri" => "https://github.com/ic-factory/lic/blob/master/CHANGELOG.md",
      "homepage_uri" => "https://github.com/ic-factory/lic",
      "source_code_uri" => "https://github.com/ic-factory/lic",
    }
  end

  s.required_ruby_version     = ">= 2.3.0"
  s.required_rubygems_version = ">= 2.5.0"

  s.add_development_dependency "automatiek", "~> 0.1.0"
  s.add_development_dependency "mustache",   "0.99.6"
  s.add_development_dependency "rake",       "~> 10.0"
  s.add_development_dependency "rdiscount",  "~> 2.2"
  s.add_development_dependency "ronn",       "~> 0.7.3"
  s.add_development_dependency "rspec",      "~> 3.6"

  base_dir = File.dirname(__FILE__).gsub(%r{([^A-Za-z0-9_\-.,:\/@\n])}, "\\\\\\1")
  s.files = IO.popen("git -C #{base_dir} ls-files -z", &:read).split("\x0").select {|f| f.match(%r{^(lib|exe)/}) }

  # we don't check in man pages, but we need to ship them because
  # we use them to generate the long-form help for each command.
  s.files += Dir.glob("man/**/*")
  # Include the CHANGELOG.md, LICENSE.md, README.md manually
  s.files += %w[CHANGELOG.md LICENSE.md README.md]
  # include the gemspec itself because warbler breaks w/o it
  s.files += %w[lic.gemspec]

  s.bindir        = "exe"
  s.executables   = %w[lic]
  s.require_paths = ["lib"]
end
