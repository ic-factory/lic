# frozen_string_literal: true

require "support/helpers"
require "support/path"

module Spec
  class TheBundle
    include Spec::Helpers
    include Spec::Path

    attr_accessor :lic_dir

    def initialize(opts = {})
      opts = opts.dup
      @lic_dir = Pathname.new(opts.delete(:lic_dir) { licd_app })
      raise "Too many options! #{opts}" unless opts.empty?
    end

    def to_s
      "the lic"
    end
    alias_method :inspect, :to_s

    def locked?
      lockfile.file?
    end

    def lockfile
      lic_dir.join("Gemfile.lock")
    end

    def locked_gems
      raise "Cannot read lockfile if it doesn't exist" unless locked?
      Lic::LockfileParser.new(lockfile.read)
    end
  end
end
