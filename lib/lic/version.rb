# frozen_string_literal: false

# Ruby 1.9.3 and old RubyGems don't play nice with frozen version strings
# rubocop:disable MutableConstant

module Lic
  # We're doing this because we might write tests that deal
  # with other versions of lic and we are unsure how to
  # handle this better.
  VERSION = "2.0.0.dev" unless defined?(::Lic::VERSION)

  def self.overwrite_loaded_gem_version
    begin
      require "rubygems"
    rescue LoadError
      return
    end
    return unless lic_spec = Gem.loaded_specs["lic"]
    return if lic_spec.version == VERSION
    lic_spec.version = Lic::VERSION
  end
  private_class_method :overwrite_loaded_gem_version
  overwrite_loaded_gem_version

  def self.lic_major_version
    @lic_major_version ||= VERSION.split(".").first.to_i
  end
end
