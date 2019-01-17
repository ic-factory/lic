# frozen_string_literal: true

module Lic
  class LicError < StandardError
    def self.status_code(code)
      define_method(:status_code) { code }
      if match = LicError.all_errors.find {|_k, v| v == code }
        error, _ = match
        raise ArgumentError,
          "Trying to register #{self} for status code #{code} but #{error} is already registered"
      end
      LicError.all_errors[self] = code
    end

    def self.all_errors
      @all_errors ||= {}
    end
  end

  class GemfileError < LicError; status_code(4); end
  class InstallError < LicError; status_code(5); end

  # Internal error, should be rescued
  class VersionConflict < LicError
    attr_reader :conflicts

    def initialize(conflicts, msg = nil)
      super(msg)
      @conflicts = conflicts
    end

    status_code(6)
  end

  class GemNotFound < LicError; status_code(7); end
  class InstallHookError < LicError; status_code(8); end
  class GemfileNotFound < LicError; status_code(10); end
  class GitError < LicError; status_code(11); end
  class DeprecatedError < LicError; status_code(12); end
  class PathError < LicError; status_code(13); end
  class GemspecError < LicError; status_code(14); end
  class InvalidOption < LicError; status_code(15); end
  class ProductionError < LicError; status_code(16); end
  class HTTPError < LicError
    status_code(17)
    def filter_uri(uri)
      URICredentialsFilter.credential_filtered_uri(uri)
    end
  end
  class RubyVersionMismatch < LicError; status_code(18); end
  class SecurityError < LicError; status_code(19); end
  class LockfileError < LicError; status_code(20); end
  class CyclicDependencyError < LicError; status_code(21); end
  class GemfileLockNotFound < LicError; status_code(22); end
  class PluginError < LicError; status_code(29); end
  class SudoNotPermittedError < LicError; status_code(30); end
  class ThreadCreationError < LicError; status_code(33); end
  class APIResponseMismatchError < LicError; status_code(34); end
  class GemfileEvalError < GemfileError; end
  class MarshalError < StandardError; end

  class PermissionError < LicError
    def initialize(path, permission_type = :write)
      @path = path
      @permission_type = permission_type
    end

    def action
      case @permission_type
      when :read then "read from"
      when :write then "write to"
      when :executable, :exec then "execute"
      else @permission_type.to_s
      end
    end

    def message
      "There was an error while trying to #{action} `#{@path}`. " \
      "It is likely that you need to grant #{@permission_type} permissions " \
      "for that path."
    end

    status_code(23)
  end

  class GemRequireError < LicError
    attr_reader :orig_exception

    def initialize(orig_exception, msg)
      full_message = msg + "\nGem Load Error is: #{orig_exception.message}\n"\
                      "Backtrace for gem load error is:\n"\
                      "#{orig_exception.backtrace.join("\n")}\n"\
                      "Lic Error Backtrace:\n"
      super(full_message)
      @orig_exception = orig_exception
    end

    status_code(24)
  end

  class YamlSyntaxError < LicError
    attr_reader :orig_exception

    def initialize(orig_exception, msg)
      super(msg)
      @orig_exception = orig_exception
    end

    status_code(25)
  end

  class TemporaryResourceError < PermissionError
    def message
      "There was an error while trying to #{action} `#{@path}`. " \
      "Some resource was temporarily unavailable. It's suggested that you try" \
      "the operation again."
    end

    status_code(26)
  end

  class VirtualProtocolError < LicError
    def message
      "There was an error relating to virtualization and file access." \
      "It is likely that you need to grant access to or mount some file system correctly."
    end

    status_code(27)
  end

  class OperationNotSupportedError < PermissionError
    def message
      "Attempting to #{action} `#{@path}` is unsupported by your OS."
    end

    status_code(28)
  end

  class NoSpaceOnDeviceError < PermissionError
    def message
      "There was an error while trying to #{action} `#{@path}`. " \
      "There was insufficient space remaining on the device."
    end

    status_code(31)
  end

  class GenericSystemCallError < LicError
    attr_reader :underlying_error

    def initialize(underlying_error, message)
      @underlying_error = underlying_error
      super("#{message}\nThe underlying system error is #{@underlying_error.class}: #{@underlying_error}")
    end

    status_code(32)
  end
end
