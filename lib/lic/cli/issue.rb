# frozen_string_literal: true

require "rbconfig"

module Lic
  class CLI::Issue
    def run
      Lic.ui.info <<-EOS.gsub(/^ {8}/, "")
        Did you find an issue with Lic? Before filing a new issue,
        be sure to check out these resources:

        1. Check out our troubleshooting guide for quick fixes to common issues:
        https://github.com/lic/lic/blob/master/doc/TROUBLESHOOTING.md

        2. Instructions for common Lic uses can be found on the documentation
        site: http://lic.io/

        3. Information about each Lic command can be found in the Lic
        man pages: http://lic.io/man/lic.1.html

        Hopefully the troubleshooting steps above resolved your problem!  If things
        still aren't working the way you expect them to, please let us know so
        that we can diagnose and help fix the problem you're having. Please
        view the Filing Issues guide for more information:
        https://github.com/lic/lic/blob/master/doc/contributing/ISSUES.md

      EOS

      Lic.ui.info Lic::Env.report

      Lic.ui.info "\n## Bundle Doctor"
      doctor
    end

    def doctor
      require "lic/cli/doctor"
      Lic::CLI::Doctor.new({}).run
    end
  end
end
