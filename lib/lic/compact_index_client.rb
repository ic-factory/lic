# frozen_string_literal: true

require "pathname"
require "set"

module Lic
  class CompactIndexClient
    DEBUG_MUTEX = Mutex.new
    def self.debug
      return unless ENV["DEBUG_COMPACT_INDEX"]
      DEBUG_MUTEX.synchronize { warn("[#{self}] #{yield}") }
    end

    class Error < StandardError; end

    require "lic/compact_index_client/cache"
    require "lic/compact_index_client/updater"

    attr_reader :directory

    # @return [Lambda] A lambda that takes an array of inputs and a block, and
    #         maps the inputs with the block in parallel.
    #
    attr_accessor :in_parallel

    def initialize(directory, fetcher)
      @directory = Pathname.new(directory)
      @updater = Updater.new(fetcher)
      @cache = Cache.new(@directory)
      @endpoints = Set.new
      @info_checksums_by_name = {}
      @parsed_checksums = false
      @mutex = Mutex.new
      @in_parallel = lambda do |inputs, &blk|
        inputs.map(&blk)
      end
    end

    def names
      Lic::CompactIndexClient.debug { "/names" }
      update(@cache.names_path, "names")
      @cache.names
    end

    def versions
      Lic::CompactIndexClient.debug { "/versions" }
      update(@cache.versions_path, "versions")
      versions, @info_checksums_by_name = @cache.versions
      versions
    end

    def dependencies(names)
      Lic::CompactIndexClient.debug { "dependencies(#{names})" }
      in_parallel.call(names) do |name|
        update_info(name)
        @cache.dependencies(name).map {|d| d.unshift(name) }
      end.flatten(1)
    end

    def spec(name, version, platform = nil)
      Lic::CompactIndexClient.debug { "spec(name = #{name}, version = #{version}, platform = #{platform})" }
      update_info(name)
      @cache.specific_dependency(name, version, platform)
    end

    def update_and_parse_checksums!
      Lic::CompactIndexClient.debug { "update_and_parse_checksums!" }
      return @info_checksums_by_name if @parsed_checksums
      update(@cache.versions_path, "versions")
      @info_checksums_by_name = @cache.checksums
      @parsed_checksums = true
    end

  private

    def update(local_path, remote_path)
      Lic::CompactIndexClient.debug { "update(#{local_path}, #{remote_path})" }
      unless synchronize { @endpoints.add?(remote_path) }
        Lic::CompactIndexClient.debug { "already fetched #{remote_path}" }
        return
      end
      @updater.update(local_path, url(remote_path))
    end

    def update_info(name)
      Lic::CompactIndexClient.debug { "update_info(#{name})" }
      path = @cache.info_path(name)
      checksum = @updater.checksum_for_file(path)
      unless existing = @info_checksums_by_name[name]
        Lic::CompactIndexClient.debug { "skipping updating info for #{name} since it is missing from versions" }
        return
      end
      if checksum == existing
        Lic::CompactIndexClient.debug { "skipping updating info for #{name} since the versions checksum matches the local checksum" }
        return
      end
      Lic::CompactIndexClient.debug { "updating info for #{name} since the versions checksum #{existing} != the local checksum #{checksum}" }
      update(path, "info/#{name}")
    end

    def url(path)
      path
    end

    def synchronize
      @mutex.synchronize { yield }
    end
  end
end
