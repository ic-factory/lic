# frozen_string_literal: true

module Lic
  def self.require_thor_actions
    Kernel.send(:require, "lic/vendor/thor/lib/thor/actions")
  end
end
require "lic/vendor/thor/lib/thor"
