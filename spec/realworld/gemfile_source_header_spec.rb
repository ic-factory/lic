# frozen_string_literal: true

require "thread"

RSpec.describe "fetching dependencies with a mirrored source", :realworld => true, :rubygems => ">= 2.0" do
  let(:mirror) { "https://server.example.org" }
  let(:original) { "http://127.0.0.1:#{@port}" }

  before do
    setup_server
    lic "config --local mirror.#{mirror} #{original}"
  end

  after do
    Artifice.deactivate
    @t.kill
    @t.join
  end

  it "sets the 'X-Gemfile-Source' header and lics successfully" do
    gemfile <<-G
      source "#{mirror}"
      gem 'weakling'
    G

    lic :install, :artifice => nil

    expect(out).to include("Installing weakling")
    expect(out).to include("Bundle complete")
    expect(the_lic).to include_gems "weakling 0.0.3"
  end

  private

  def setup_server
    require_rack
    @port = find_unused_port
    @server_uri = "http://127.0.0.1:#{@port}"

    require File.expand_path("../../support/artifice/endpoint_mirror_source", __FILE__)

    @t = Thread.new do
      Rack::Server.start(:app       => EndpointMirrorSource,
                         :Host      => "0.0.0.0",
                         :Port      => @port,
                         :server    => "webrick",
                         :AccessLog => [],
                         :Logger    => Spec::SilentLogger.new)
    end.run

    wait_for_server("127.0.0.1", @port)
  end
end
