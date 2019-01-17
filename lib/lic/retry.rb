# frozen_string_literal: true

module Lic
  # General purpose class for retrying code that may fail
  class Retry
    attr_accessor :name, :total_runs, :current_run

    class << self
      def default_attempts
        default_retries + 1
      end
      alias_method :attempts, :default_attempts

      def default_retries
        Lic.settings[:retry]
      end
    end

    def initialize(name, exceptions = nil, retries = self.class.default_retries)
      @name = name
      @retries = retries
      @exceptions = Array(exceptions) || []
      @total_runs = @retries + 1 # will run once, then upto attempts.times
    end

    def attempt(&block)
      @current_run = 0
      @failed      = false
      @error       = nil
      run(&block) while keep_trying?
      @result
    end
    alias_method :attempts, :attempt

  private

    def run(&block)
      @failed = false
      @current_run += 1
      @result = block.call
    rescue => e
      fail_attempt(e)
    end

    def fail_attempt(e)
      @failed = true
      if last_attempt? || @exceptions.any? {|k| e.is_a?(k) }
        Lic.ui.info "" unless Lic.ui.debug?
        raise e
      end
      return true unless name
      Lic.ui.info "" unless Lic.ui.debug? # Add new line incase dots preceded this
      Lic.ui.warn "Retrying #{name} due to error (#{current_run.next}/#{total_runs}): #{e.class} #{e.message}", Lic.ui.debug?
    end

    def keep_trying?
      return true  if current_run.zero?
      return false if last_attempt?
      return true  if @failed
    end

    def last_attempt?
      current_run >= total_runs
    end
  end
end
