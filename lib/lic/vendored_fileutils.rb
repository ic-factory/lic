# frozen_string_literal: true

module Lic; end
if RUBY_VERSION >= "2.4"
  require "lic/vendor/fileutils/lib/fileutils"
else
  # the version we vendor is 2.4+
  require "fileutils"
end
