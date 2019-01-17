# frozen_string_literal: true

require "lic/shared_helpers"

if Lic::SharedHelpers.in_lic?
  require "lic"

  if STDOUT.tty? || ENV["LIC_FORCE_TTY"]
    begin
      Lic.setup
    rescue Lic::LicError => e
      puts "\e[31m#{e.message}\e[0m"
      puts e.backtrace.join("\n") if ENV["DEBUG"]
      if e.is_a?(Lic::GemNotFound)
        puts "\e[33mRun `lic install` to install missing gems.\e[0m"
      end
      exit e.status_code
    end
  else
    Lic.setup
  end

  # Add lic to the load path after disabling system gems
  lic_lib = File.expand_path("../..", __FILE__)
  $LOAD_PATH.unshift(lic_lib) unless $LOAD_PATH.include?(lic_lib)

  Lic.ui = nil
end
