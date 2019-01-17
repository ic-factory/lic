# frozen_string_literal: true

require "rake/clean"
CLOBBER.include "pkg"

require "lic/gem_helper"
Lic::GemHelper.install_tasks
