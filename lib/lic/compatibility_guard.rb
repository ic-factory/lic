# frozen_string_literal: false

require "rubygems"
require "lic/version"

if Lic::VERSION.split(".").first.to_i >= 2
  if Gem::Version.new(Object::RUBY_VERSION.dup) < Gem::Version.new("2.3")
    abort "Lic 2 requires Ruby 2.3 or later. Either install lic 1 or update to a supported Ruby version."
  end

  if Gem::Version.new(Gem::VERSION.dup) < Gem::Version.new("2.5")
    abort "Lic 2 requires RubyGems 2.5 or later. Either install lic 1 or update to a supported RubyGems version."
  end
end
