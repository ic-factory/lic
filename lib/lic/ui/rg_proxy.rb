# frozen_string_literal: true

require "lic/ui"
require "rubygems/user_interaction"

module Lic
  module UI
    class RGProxy < ::Gem::SilentUI
      def initialize(ui)
        @ui = ui
        super()
      end

      def say(message)
        @ui && @ui.debug(message)
      end
    end
  end
end
