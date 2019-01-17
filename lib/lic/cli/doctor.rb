# frozen_string_literal: true

require "rbconfig"

module Lic
  class CLI::Doctor
    DARWIN_REGEX = /\s+(.+) \(compatibility /
    LDD_REGEX = /\t\S+ => (\S+) \(\S+\)/

    attr_reader :options

    def initialize(options)
      @options = options
    end

    def otool_available?
      Lic.which("otool")
    end

    def ldd_available?
      Lic.which("ldd")
    end

    def dylibs_darwin(path)
      output = `/usr/bin/otool -L "#{path}"`.chomp
      dylibs = output.split("\n")[1..-1].map {|l| l.match(DARWIN_REGEX).captures[0] }.uniq
      # ignore @rpath and friends
      dylibs.reject {|dylib| dylib.start_with? "@" }
    end

    def dylibs_ldd(path)
      output = `/usr/bin/ldd "#{path}"`.chomp
      output.split("\n").map do |l|
        match = l.match(LDD_REGEX)
        next if match.nil?
        match.captures[0]
      end.compact
    end

    def dylibs(path)
      case RbConfig::CONFIG["host_os"]
      when /darwin/
        return [] unless otool_available?
        dylibs_darwin(path)
      when /(linux|solaris|bsd)/
        return [] unless ldd_available?
        dylibs_ldd(path)
      else # Windows, etc.
        Lic.ui.warn("Dynamic library check not supported on this platform.")
        []
      end
    end

    def lics_for_gem(spec)
      Dir.glob("#{spec.full_gem_path}/**/*.lic")
    end

    def check!
      require "lic/cli/check"
      Lic::CLI::Check.new({}).run
    end

    def run
      Lic.ui.level = "error" if options[:quiet]
      Lic.settings.validate!
      check!

      definition = Lic.definition
      broken_links = {}

      definition.specs.each do |spec|
        lics_for_gem(spec).each do |lic|
          bad_paths = dylibs(lic).select {|f| !File.exist?(f) }
          if bad_paths.any?
            broken_links[spec] ||= []
            broken_links[spec].concat(bad_paths)
          end
        end
      end

      permissions_valid = check_home_permissions

      if broken_links.any?
        message = "The following gems are missing OS dependencies:"
        broken_links.map do |spec, paths|
          paths.uniq.map do |path|
            "\n * #{spec.name}: #{path}"
          end
        end.flatten.sort.each {|m| message += m }
        raise ProductionError, message
      elsif !permissions_valid
        Lic.ui.info "No issues found with the installed lic"
      end
    end

  private

    def check_home_permissions
      require "find"
      files_not_readable_or_writable = []
      files_not_rw_and_owned_by_different_user = []
      files_not_owned_by_current_user_but_still_rw = []
      Find.find(Lic.home.to_s).each do |f|
        if !File.writable?(f) || !File.readable?(f)
          if File.stat(f).uid != Process.uid
            files_not_rw_and_owned_by_different_user << f
          else
            files_not_readable_or_writable << f
          end
        elsif File.stat(f).uid != Process.uid
          files_not_owned_by_current_user_but_still_rw << f
        end
      end

      ok = true
      if files_not_owned_by_current_user_but_still_rw.any?
        Lic.ui.warn "Files exist in the Lic home that are owned by another " \
          "user, but are still readable/writable. These files are:\n - #{files_not_owned_by_current_user_but_still_rw.join("\n - ")}"

        ok = false
      end

      if files_not_rw_and_owned_by_different_user.any?
        Lic.ui.warn "Files exist in the Lic home that are owned by another " \
          "user, and are not readable/writable. These files are:\n - #{files_not_rw_and_owned_by_different_user.join("\n - ")}"

        ok = false
      end

      if files_not_readable_or_writable.any?
        Lic.ui.warn "Files exist in the Lic home that are not " \
          "readable/writable by the current user. These files are:\n - #{files_not_readable_or_writable.join("\n - ")}"

        ok = false
      end

      ok
    end
  end
end
