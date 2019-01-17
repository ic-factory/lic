# frozen_string_literal: true

module Lic
  class EnvironmentPreserver
    INTENTIONALLY_NIL = "LIC_ENVIRONMENT_PRESERVER_INTENTIONALLY_NIL".freeze
    LIC_KEYS = %w[
      LIC_BIN_PATH
      LIC_GEMFILE
      LIC_ORIG_MANPATH
      LIC_VERSION
      GEM_HOME
      GEM_PATH
      MANPATH
      PATH
      RB_USER_INSTALL
      RUBYLIB
      RUBYOPT
    ].map(&:freeze).freeze
    LIC_PREFIX = "LIC_ORIG_".freeze

    # @param env [ENV]
    # @param keys [Array<String>]
    def initialize(env, keys)
      @original = env.to_hash
      @keys = keys
      @prefix = LIC_PREFIX
    end

    # @return [Hash]
    def backup
      env = @original.clone
      @keys.each do |key|
        value = env[key]
        if !value.nil? && !value.empty?
          env[@prefix + key] ||= value
        elsif value.nil?
          env[@prefix + key] ||= INTENTIONALLY_NIL
        end
      end
      env
    end

    # @return [Hash]
    def restore
      env = @original.clone
      @keys.each do |key|
        value_original = env[@prefix + key]
        next if value_original.nil? || value_original.empty?
        if value_original == INTENTIONALLY_NIL
          env.delete(key)
        else
          env[key] = value_original
        end
        env.delete(@prefix + key)
      end
      env
    end
  end
end
