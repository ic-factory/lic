# frozen_string_literal: true

RSpec.describe "compact index api" do
  let(:source_hostname) { "localgemserver.test" }
  let(:source_uri) { "http://#{source_hostname}" }

  it "should use the API" do
    gemfile <<-G
      source "#{source_uri}"
      gem "rack"
    G

    lic! :install, :artifice => "compact_index"
    expect(out).to include("Fetching gem metadata from #{source_uri}")
    expect(the_lic).to include_gems "rack 1.0.0"
  end

  it "should URI encode gem names" do
    gemfile <<-G
      source "#{source_uri}"
      gem " sinatra"
    G

    lic :install, :artifice => "compact_index"
    expect(out).to include("' sinatra' is not a valid gem name because it contains whitespace.")
  end

  it "should handle nested dependencies" do
    gemfile <<-G
      source "#{source_uri}"
      gem "rails"
    G

    lic! :install, :artifice => "compact_index"
    expect(out).to include("Fetching gem metadata from #{source_uri}")
    expect(the_lic).to include_gems(
      "rails 2.3.2",
      "actionpack 2.3.2",
      "activerecord 2.3.2",
      "actionmailer 2.3.2",
      "activeresource 2.3.2",
      "activesupport 2.3.2"
    )
  end

  it "should handle case sensitivity conflicts" do
    build_repo4 do
      build_gem "rack", "1.0" do |s|
        s.add_runtime_dependency("Rack", "0.1")
      end
      build_gem "Rack", "0.1"
    end

    install_gemfile! <<-G, :artifice => "compact_index", :env => { "LIC_SPEC_GEM_REPO" => gem_repo4 }
      source "#{source_uri}"
      gem "rack", "1.0"
      gem "Rack", "0.1"
    G

    # can't use `include_gems` here since the `require` will conflict on a
    # case-insensitive FS
    run! "Lic.require; puts Gem.loaded_specs.values_at('rack', 'Rack').map(&:full_name)"
    expect(last_command.stdout).to eq("rack-1.0\nRack-0.1")
  end

  it "should handle multiple gem dependencies on the same gem" do
    gemfile <<-G
      source "#{source_uri}"
      gem "net-sftp"
    G

    lic! :install, :artifice => "compact_index"
    expect(the_lic).to include_gems "net-sftp 1.1.1"
  end

  it "should use the endpoint when using --deployment" do
    gemfile <<-G
      source "#{source_uri}"
      gem "rack"
    G
    lic! :install, :artifice => "compact_index"

    lic! :install, forgotten_command_line_options(:deployment => true, :path => "vendor/lic").merge(:artifice => "compact_index")
    expect(out).to include("Fetching gem metadata from #{source_uri}")
    expect(the_lic).to include_gems "rack 1.0.0"
  end

  it "handles git dependencies that are in rubygems" do
    build_git "foo" do |s|
      s.executables = "foobar"
      s.add_dependency "rails", "2.3.2"
    end

    gemfile <<-G
      source "#{source_uri}"
      git "file:///#{lib_path("foo-1.0")}" do
        gem 'foo'
      end
    G

    lic! :install, :artifice => "compact_index"

    expect(the_lic).to include_gems("rails 2.3.2")
  end

  it "handles git dependencies that are in rubygems using --deployment" do
    build_git "foo" do |s|
      s.executables = "foobar"
      s.add_dependency "rails", "2.3.2"
    end

    gemfile <<-G
      source "#{source_uri}"
      gem 'foo', :git => "file:///#{lib_path("foo-1.0")}"
    G

    lic! :install, :artifice => "compact_index"

    lic "install --deployment", :artifice => "compact_index"

    expect(the_lic).to include_gems("rails 2.3.2")
  end

  it "doesn't fail if you only have a git gem with no deps when using --deployment" do
    build_git "foo"
    gemfile <<-G
      source "#{source_uri}"
      gem 'foo', :git => "file:///#{lib_path("foo-1.0")}"
    G

    lic "install", :artifice => "compact_index"
    lic! :install, forgotten_command_line_options(:deployment => true).merge(:artifice => "compact_index")

    expect(the_lic).to include_gems("foo 1.0")
  end

  it "falls back when the API errors out" do
    simulate_platform mswin

    gemfile <<-G
      source "#{source_uri}"
      gem "rcov"
    G

    lic! :install, :artifice => "windows"
    expect(out).to include("Fetching source index from #{source_uri}")
    expect(the_lic).to include_gems "rcov 1.0.0"
  end

  it "falls back when the API URL returns 403 Forbidden" do
    gemfile <<-G
      source "#{source_uri}"
      gem "rack"
    G

    lic! :install, :verbose => true, :artifice => "compact_index_forbidden"
    expect(out).to include("Fetching gem metadata from #{source_uri}")
    expect(the_lic).to include_gems "rack 1.0.0"
  end

  it "falls back when the versions endpoint has a checksum mismatch" do
    gemfile <<-G
      source "#{source_uri}"
      gem "rack"
    G

    lic! :install, :verbose => true, :artifice => "compact_index_checksum_mismatch"
    expect(out).to include("Fetching gem metadata from #{source_uri}")
    expect(out).to include <<-'WARN'
The checksum of /versions does not match the checksum provided by the server! Something is wrong (local checksum is "\"d41d8cd98f00b204e9800998ecf8427e\"", was expecting "\"123\"").
    WARN
    expect(the_lic).to include_gems "rack 1.0.0"
  end

  it "falls back when the user's home directory does not exist or is not writable" do
    ENV["HOME"] = tmp("missing_home").to_s

    gemfile <<-G
      source "#{source_uri}"
      gem "rack"
    G

    lic! :install, :artifice => "compact_index"
    expect(out).to include("Fetching gem metadata from #{source_uri}")
    expect(the_lic).to include_gems "rack 1.0.0"
  end

  it "handles host redirects" do
    gemfile <<-G
      source "#{source_uri}"
      gem "rack"
    G

    lic! :install, :artifice => "compact_index_host_redirect"
    expect(the_lic).to include_gems "rack 1.0.0"
  end

  it "handles host redirects without Net::HTTP::Persistent" do
    gemfile <<-G
      source "#{source_uri}"
      gem "rack"
    G

    FileUtils.mkdir_p lib_path
    File.open(lib_path("disable_net_http_persistent.rb"), "w") do |h|
      h.write <<-H
        module Kernel
          alias require_without_disabled_net_http require
          def require(*args)
            raise LoadError, 'simulated' if args.first == 'openssl' && !caller.grep(/vendored_persistent/).empty?
            require_without_disabled_net_http(*args)
          end
        end
      H
    end

    lic! :install, :artifice => "compact_index_host_redirect", :requires => [lib_path("disable_net_http_persistent.rb")]
    expect(out).to_not match(/Too many redirects/)
    expect(the_lic).to include_gems "rack 1.0.0"
  end

  it "times out when Lic::Fetcher redirects too much" do
    gemfile <<-G
      source "#{source_uri}"
      gem "rack"
    G

    lic :install, :artifice => "compact_index_redirects"
    expect(out).to match(/Too many redirects/)
  end

  context "when --full-index is specified" do
    it "should use the modern index for install" do
      gemfile <<-G
        source "#{source_uri}"
        gem "rack"
      G

      lic "install --full-index", :artifice => "compact_index"
      expect(out).to include("Fetching source index from #{source_uri}")
      expect(the_lic).to include_gems "rack 1.0.0"
    end

    it "should use the modern index for update" do
      gemfile <<-G
        source "#{source_uri}"
        gem "rack"
      G

      lic! "update --full-index", :artifice => "compact_index", :all => lic_update_requires_all?
      expect(out).to include("Fetching source index from #{source_uri}")
      expect(the_lic).to include_gems "rack 1.0.0"
    end
  end

  it "does not double check for gems that are only installed locally" do
    system_gems %w[rack-1.0.0 thin-1.0 net_a-1.0]
    lic! "config --local path.system true"
    ENV["LIC_SPEC_ALL_REQUESTS"] = strip_whitespace(<<-EOS).strip
      #{source_uri}/versions
      #{source_uri}/info/rack
    EOS

    install_gemfile! <<-G, :artifice => "compact_index", :verbose => true
      source "#{source_uri}"
      gem "rack"
    G

    expect(last_command.stdboth).not_to include "Double checking"
  end

  it "fetches again when more dependencies are found in subsequent sources", :lic => "< 2" do
    build_repo2 do
      build_gem "back_deps" do |s|
        s.add_dependency "foo"
      end
      FileUtils.rm_rf Dir[gem_repo2("gems/foo-*.gem")]
    end

    gemfile <<-G
      source "#{source_uri}"
      source "#{source_uri}/extra"
      gem "back_deps"
    G

    lic! :install, :artifice => "compact_index_extra"
    expect(the_lic).to include_gems "back_deps 1.0", "foo 1.0"
  end

  it "fetches again when more dependencies are found in subsequent sources with source blocks" do
    build_repo2 do
      build_gem "back_deps" do |s|
        s.add_dependency "foo"
      end
      FileUtils.rm_rf Dir[gem_repo2("gems/foo-*.gem")]
    end

    install_gemfile! <<-G, :artifice => "compact_index_extra", :verbose => true
      source "#{source_uri}"
      source "#{source_uri}/extra" do
        gem "back_deps"
      end
    G

    expect(the_lic).to include_gems "back_deps 1.0", "foo 1.0"
  end

  it "fetches gem versions even when those gems are already installed" do
    gemfile <<-G
      source "#{source_uri}"
      gem "rack", "1.0.0"
    G
    lic! :install, :artifice => "compact_index_extra_api"
    expect(the_lic).to include_gems "rack 1.0.0"

    build_repo4 do
      build_gem "rack", "1.2" do |s|
        s.executables = "rackup"
      end
    end

    gemfile <<-G
      source "#{source_uri}" do; end
      source "#{source_uri}/extra"
      gem "rack", "1.2"
    G
    lic! :install, :artifice => "compact_index_extra_api"
    expect(the_lic).to include_gems "rack 1.2"
  end

  it "considers all possible versions of dependencies from all api gem sources", :lic => "< 2" do
    # In this scenario, the gem "somegem" only exists in repo4.  It depends on specific version of activesupport that
    # exists only in repo1.  There happens also be a version of activesupport in repo4, but not the one that version 1.0.0
    # of somegem wants. This test makes sure that lic actually finds version 1.2.3 of active support in the other
    # repo and installs it.
    build_repo4 do
      build_gem "activesupport", "1.2.0"
      build_gem "somegem", "1.0.0" do |s|
        s.add_dependency "activesupport", "1.2.3" # This version exists only in repo1
      end
    end

    gemfile <<-G
      source "#{source_uri}"
      source "#{source_uri}/extra"
      gem 'somegem', '1.0.0'
    G

    lic! :install, :artifice => "compact_index_extra_api"

    expect(the_lic).to include_gems "somegem 1.0.0"
    expect(the_lic).to include_gems "activesupport 1.2.3"
  end

  it "considers all possible versions of dependencies from all api gem sources when using blocks", :lic => "< 2" do
    # In this scenario, the gem "somegem" only exists in repo4.  It depends on specific version of activesupport that
    # exists only in repo1.  There happens also be a version of activesupport in repo4, but not the one that version 1.0.0
    # of somegem wants. This test makes sure that lic actually finds version 1.2.3 of active support in the other
    # repo and installs it.
    build_repo4 do
      build_gem "activesupport", "1.2.0"
      build_gem "somegem", "1.0.0" do |s|
        s.add_dependency "activesupport", "1.2.3" # This version exists only in repo1
      end
    end

    gemfile <<-G
      source "#{source_uri}"
      source "#{source_uri}/extra" do
        gem 'somegem', '1.0.0'
      end
    G

    lic! :install, :artifice => "compact_index_extra_api"

    expect(the_lic).to include_gems "somegem 1.0.0"
    expect(the_lic).to include_gems "activesupport 1.2.3"
  end

  it "prints API output properly with back deps" do
    build_repo2 do
      build_gem "back_deps" do |s|
        s.add_dependency "foo"
      end
      FileUtils.rm_rf Dir[gem_repo2("gems/foo-*.gem")]
    end

    gemfile <<-G
      source "#{source_uri}"
      source "#{source_uri}/extra" do
        gem "back_deps"
      end
    G

    lic! :install, :artifice => "compact_index_extra"

    expect(out).to include("Fetching gem metadata from http://localgemserver.test/")
    expect(out).to include("Fetching source index from http://localgemserver.test/extra")
  end

  it "does not fetch every spec if the index of gems is large when doing back deps" do
    build_repo2 do
      build_gem "back_deps" do |s|
        s.add_dependency "foo"
      end
      build_gem "missing"
      # need to hit the limit
      1.upto(Lic::Source::Rubygems::API_REQUEST_LIMIT) do |i|
        build_gem "gem#{i}"
      end

      FileUtils.rm_rf Dir[gem_repo2("gems/foo-*.gem")]
    end

    gemfile <<-G
      source "#{source_uri}"
      source "#{source_uri}/extra" do
        gem "back_deps"
      end
    G

    lic! :install, :artifice => "compact_index_extra_missing"
    expect(the_lic).to include_gems "back_deps 1.0"
  end

  it "does not fetch every spec if the index of gems is large when doing back deps & everything is the compact index" do
    build_repo4 do
      build_gem "back_deps" do |s|
        s.add_dependency "foo"
      end
      build_gem "missing"
      # need to hit the limit
      1.upto(Lic::Source::Rubygems::API_REQUEST_LIMIT) do |i|
        build_gem "gem#{i}"
      end

      FileUtils.rm_rf Dir[gem_repo4("gems/foo-*.gem")]
    end

    install_gemfile! <<-G, :artifice => "compact_index_extra_api_missing"
      source "#{source_uri}"
      source "#{source_uri}/extra" do
        gem "back_deps"
      end
    G

    expect(the_lic).to include_gem "back_deps 1.0"
  end

  it "uses the endpoint if all sources support it" do
    gemfile <<-G
      source "#{source_uri}"

      gem 'foo'
    G

    lic! :install, :artifice => "compact_index_api_missing"
    expect(the_lic).to include_gems "foo 1.0"
  end

  it "fetches again when more dependencies are found in subsequent sources using --deployment", :lic => "< 2" do
    build_repo2 do
      build_gem "back_deps" do |s|
        s.add_dependency "foo"
      end
      FileUtils.rm_rf Dir[gem_repo2("gems/foo-*.gem")]
    end

    gemfile <<-G
      source "#{source_uri}"
      source "#{source_uri}/extra"
      gem "back_deps"
    G

    lic! :install, :artifice => "compact_index_extra"

    lic "install --deployment", :artifice => "compact_index_extra"
    expect(the_lic).to include_gems "back_deps 1.0"
  end

  it "fetches again when more dependencies are found in subsequent sources using --deployment with blocks" do
    build_repo2 do
      build_gem "back_deps" do |s|
        s.add_dependency "foo"
      end
      FileUtils.rm_rf Dir[gem_repo2("gems/foo-*.gem")]
    end

    gemfile <<-G
      source "#{source_uri}"
      source "#{source_uri}/extra" do
        gem "back_deps"
      end
    G

    lic! :install, :artifice => "compact_index_extra"

    lic "install --deployment", :artifice => "compact_index_extra"
    expect(the_lic).to include_gems "back_deps 1.0"
  end

  it "does not refetch if the only unmet dependency is lic" do
    gemfile <<-G
      source "#{source_uri}"

      gem "lic_dep"
    G

    lic! :install, :artifice => "compact_index"
    expect(out).to include("Fetching gem metadata from #{source_uri}")
  end

  it "should install when EndpointSpecification has a bin dir owned by root", :sudo => true do
    sudo "mkdir -p #{system_gem_path("bin")}"
    sudo "chown -R root #{system_gem_path("bin")}"

    gemfile <<-G
      source "#{source_uri}"
      gem "rails"
    G
    lic! :install, :artifice => "compact_index"
    expect(the_lic).to include_gems "rails 2.3.2"
  end

  it "installs the binstubs", :lic => "< 2" do
    gemfile <<-G
      source "#{source_uri}"
      gem "rack"
    G

    lic "install --binstubs", :artifice => "compact_index"

    gembin "rackup"
    expect(out).to eq("1.0.0")
  end

  it "installs the bins when using --path and uses autoclean", :lic => "< 2" do
    gemfile <<-G
      source "#{source_uri}"
      gem "rack"
    G

    lic "install --path vendor/lic", :artifice => "compact_index"

    expect(vendored_gems("bin/rackup")).to exist
  end

  it "installs the bins when using --path and uses lic clean", :lic => "< 2" do
    gemfile <<-G
      source "#{source_uri}"
      gem "rack"
    G

    lic "install --path vendor/lic --no-clean", :artifice => "compact_index"

    expect(vendored_gems("bin/rackup")).to exist
  end

  it "prints post_install_messages" do
    gemfile <<-G
      source "#{source_uri}"
      gem 'rack-obama'
    G

    lic! :install, :artifice => "compact_index"
    expect(out).to include("Post-install message from rack:")
  end

  it "should display the post install message for a dependency" do
    gemfile <<-G
      source "#{source_uri}"
      gem 'rack_middleware'
    G

    lic! :install, :artifice => "compact_index"
    expect(out).to include("Post-install message from rack:")
    expect(out).to include("Rack's post install message")
  end

  context "when using basic authentication" do
    let(:user)     { "user" }
    let(:password) { "pass" }
    let(:basic_auth_source_uri) do
      uri          = URI.parse(source_uri)
      uri.user     = user
      uri.password = password

      uri
    end

    it "passes basic authentication details and strips out creds" do
      gemfile <<-G
        source "#{basic_auth_source_uri}"
        gem "rack"
      G

      lic! :install, :artifice => "compact_index_basic_authentication"
      expect(out).not_to include("#{user}:#{password}")
      expect(the_lic).to include_gems "rack 1.0.0"
    end

    it "strips http basic authentication creds for modern index" do
      gemfile <<-G
        source "#{basic_auth_source_uri}"
        gem "rack"
      G

      lic! :install, :artifice => "endopint_marshal_fail_basic_authentication"
      expect(out).not_to include("#{user}:#{password}")
      expect(the_lic).to include_gems "rack 1.0.0"
    end

    it "strips http basic auth creds when it can't reach the server" do
      gemfile <<-G
        source "#{basic_auth_source_uri}"
        gem "rack"
      G

      lic :install, :artifice => "endpoint_500"
      expect(out).not_to include("#{user}:#{password}")
    end

    it "strips http basic auth creds when warning about ambiguous sources", :lic => "< 2" do
      gemfile <<-G
        source "#{basic_auth_source_uri}"
        source "file://#{gem_repo1}"
        gem "rack"
      G

      lic! :install, :artifice => "compact_index_basic_authentication"
      expect(out).to include("Warning: the gem 'rack' was found in multiple sources.")
      expect(out).not_to include("#{user}:#{password}")
      expect(the_lic).to include_gems "rack 1.0.0"
    end

    it "does not pass the user / password to different hosts on redirect" do
      gemfile <<-G
        source "#{basic_auth_source_uri}"
        gem "rack"
      G

      lic! :install, :artifice => "compact_index_creds_diff_host"
      expect(the_lic).to include_gems "rack 1.0.0"
    end

    describe "with authentication details in lic config" do
      before do
        gemfile <<-G
          source "#{source_uri}"
          gem "rack"
        G
      end

      it "reads authentication details by host name from lic config" do
        lic "config #{source_hostname} #{user}:#{password}"

        lic! :install, :artifice => "compact_index_strict_basic_authentication"

        expect(out).to include("Fetching gem metadata from #{source_uri}")
        expect(the_lic).to include_gems "rack 1.0.0"
      end

      it "reads authentication details by full url from lic config" do
        # The trailing slash is necessary here; Fetcher canonicalizes the URI.
        lic "config #{source_uri}/ #{user}:#{password}"

        lic! :install, :artifice => "compact_index_strict_basic_authentication"

        expect(out).to include("Fetching gem metadata from #{source_uri}")
        expect(the_lic).to include_gems "rack 1.0.0"
      end

      it "should use the API" do
        lic "config #{source_hostname} #{user}:#{password}"
        lic! :install, :artifice => "compact_index_strict_basic_authentication"
        expect(out).to include("Fetching gem metadata from #{source_uri}")
        expect(the_lic).to include_gems "rack 1.0.0"
      end

      it "prefers auth supplied in the source uri" do
        gemfile <<-G
          source "#{basic_auth_source_uri}"
          gem "rack"
        G

        lic "config #{source_hostname} otheruser:wrong"

        lic! :install, :artifice => "compact_index_strict_basic_authentication"
        expect(the_lic).to include_gems "rack 1.0.0"
      end

      it "shows instructions if auth is not provided for the source" do
        lic :install, :artifice => "compact_index_strict_basic_authentication"
        expect(out).to include("lic config #{source_hostname} username:password")
      end

      it "fails if authentication has already been provided, but failed" do
        lic "config #{source_hostname} #{user}:wrong"

        lic :install, :artifice => "compact_index_strict_basic_authentication"
        expect(out).to include("Bad username or password")
      end
    end

    describe "with no password" do
      let(:password) { nil }

      it "passes basic authentication details" do
        gemfile <<-G
          source "#{basic_auth_source_uri}"
          gem "rack"
        G

        lic! :install, :artifice => "compact_index_basic_authentication"
        expect(the_lic).to include_gems "rack 1.0.0"
      end
    end
  end

  context "when ruby is compiled without openssl" do
    before do
      # Install a monkeypatch that reproduces the effects of openssl being
      # missing when the fetcher runs, as happens in real life. The reason
      # we can't just overwrite openssl.rb is that Artifice uses it.
      licd_app("broken_ssl").mkpath
      licd_app("broken_ssl/openssl.rb").open("w") do |f|
        f.write <<-RUBY
          raise LoadError, "cannot load such file -- openssl"
        RUBY
      end
    end

    it "explains what to do to get it" do
      gemfile <<-G
        source "#{source_uri.gsub(/http/, "https")}"
        gem "rack"
      G

      lic :install, :env => { "RUBYOPT" => "-I#{licd_app("broken_ssl")}" }
      expect(out).to include("OpenSSL")
    end
  end

  context "when SSL certificate verification fails" do
    it "explains what happened" do
      # Install a monkeypatch that reproduces the effects of openssl raising
      # a certificate validation error when RubyGems tries to connect.
      gemfile <<-G
        class Net::HTTP
          def start
            raise OpenSSL::SSL::SSLError, "certificate verify failed"
          end
        end

        source "#{source_uri.gsub(/http/, "https")}"
        gem "rack"
      G

      lic :install
      expect(out).to match(/could not verify the SSL certificate/i)
    end
  end

  context ".gemrc with sources is present" do
    before do
      File.open(home(".gemrc"), "w") do |file|
        file.puts({ :sources => ["https://rubygems.org"] }.to_yaml)
      end
    end

    after do
      home(".gemrc").rmtree
    end

    it "uses other sources declared in the Gemfile" do
      gemfile <<-G
        source "#{source_uri}"
        gem 'rack'
      G

      lic! :install, :artifice => "compact_index_forbidden"
    end
  end

  it "performs partial update with a non-empty range" do
    gemfile <<-G
      source "#{source_uri}"
      gem 'rack', '0.9.1'
    G

    # Initial install creates the cached versions file
    lic! :install, :artifice => "compact_index"

    # Update the Gemfile so we can check subsequent install was successful
    gemfile <<-G
      source "#{source_uri}"
      gem 'rack', '1.0.0'
    G

    # Second install should make only a partial request to /versions
    lic! :install, :artifice => "compact_index_partial_update"

    expect(the_lic).to include_gems "rack 1.0.0"
  end

  it "performs partial update while local cache is updated by another process" do
    gemfile <<-G
      source "#{source_uri}"
      gem 'rack'
    G

    # Create an empty file to trigger a partial download
    versions = File.join(Lic.rubygems.user_home, ".lic", "cache", "compact_index",
      "localgemserver.test.80.dd34752a738ee965a2a4298dc16db6c5", "versions")
    FileUtils.mkdir_p(File.dirname(versions))
    FileUtils.touch(versions)

    lic! :install, :artifice => "compact_index_concurrent_download"

    expect(File.read(versions)).to start_with("created_at")
    expect(the_lic).to include_gems "rack 1.0.0"
  end

  it "performs full update of compact index info cache if range is not satisfiable" do
    gemfile <<-G
      source "#{source_uri}"
      gem 'rack', '0.9.1'
    G

    rake_info_path = File.join(Lic.rubygems.user_home, ".lic", "cache", "compact_index",
      "localgemserver.test.80.dd34752a738ee965a2a4298dc16db6c5", "info", "rack")

    lic! :install, :artifice => "compact_index"

    expected_rack_info_content = File.read(rake_info_path)

    # Modify the cache files. We expect them to be reset to the normal ones when we re-run :install
    File.open(rake_info_path, "w") {|f| f << (expected_rack_info_content + "this is different") }

    # Update the Gemfile so the next install does its normal things
    gemfile <<-G
      source "#{source_uri}"
      gem 'rack', '1.0.0'
    G

    # The cache files now being longer means the requested range is going to be not satisfiable
    # Lic must end up requesting the whole file to fix things up.
    lic! :install, :artifice => "compact_index_range_not_satisfiable"

    resulting_rack_info_content = File.read(rake_info_path)

    expect(resulting_rack_info_content).to eq(expected_rack_info_content)
  end

  it "fails gracefully when the source URI has an invalid scheme" do
    install_gemfile <<-G
      source "htps://rubygems.org"
      gem "rack"
    G
    expect(exitstatus).to eq(15) if exitstatus
    expect(out).to end_with(<<-E.strip)
      The request uri `htps://index.rubygems.org/versions` has an invalid scheme (`htps`). Did you mean `http` or `https`?
    E
  end

  describe "checksum validation", :rubygems => ">= 2.3.0" do
    it "raises when the checksum does not match" do
      install_gemfile <<-G, :artifice => "compact_index_wrong_gem_checksum"
        source "#{source_uri}"
        gem "rack"
      G

      expect(exitstatus).to eq(19) if exitstatus
      expect(out).
        to  include("Lic cannot continue installing rack (1.0.0).").
        and include("The checksum for the downloaded `rack-1.0.0.gem` does not match the checksum given by the server.").
        and include("This means the contents of the downloaded gem is different from what was uploaded to the server, and could be a potential security issue.").
        and include("To resolve this issue:").
        and include("1. delete the downloaded gem located at: `#{default_lic_path}/gems/rack-1.0.0/rack-1.0.0.gem`").
        and include("2. run `lic install`").
        and include("If you wish to continue installing the downloaded gem, and are certain it does not pose a security issue despite the mismatching checksum, do the following:").
        and include("1. run `lic config disable_checksum_validation true` to turn off checksum verification").
        and include("2. run `lic install`").
        and match(/\(More info: The expected SHA256 checksum was "#{"ab" * 22}", but the checksum for the downloaded gem was ".+?"\.\)/)
    end

    it "raises when the checksum is the wrong length" do
      install_gemfile <<-G, :artifice => "compact_index_wrong_gem_checksum", :env => { "LIC_SPEC_RACK_CHECKSUM" => "checksum!" }
        source "#{source_uri}"
        gem "rack"
      G
      expect(exitstatus).to eq(5) if exitstatus
      expect(out).to include("The given checksum for rack-1.0.0 (\"checksum!\") is not a valid SHA256 hexdigest nor base64digest")
    end

    it "does not raise when disable_checksum_validation is set" do
      lic! "config disable_checksum_validation true"
      install_gemfile! <<-G, :artifice => "compact_index_wrong_gem_checksum"
        source "#{source_uri}"
        gem "rack"
      G
    end
  end

  it "works when cache dir is world-writable" do
    install_gemfile! <<-G, :artifice => "compact_index"
      File.umask(0000)
      source "#{source_uri}"
      gem "rack"
    G
  end

  it "doesn't explode when the API dependencies are wrong" do
    install_gemfile <<-G, :artifice => "compact_index_wrong_dependencies", :env => { "DEBUG" => "true" }
      source "#{source_uri}"
      gem "rails"
    G
    deps = [Gem::Dependency.new("rake", "= 10.0.2"),
            Gem::Dependency.new("actionpack", "= 2.3.2"),
            Gem::Dependency.new("activerecord", "= 2.3.2"),
            Gem::Dependency.new("actionmailer", "= 2.3.2"),
            Gem::Dependency.new("activeresource", "= 2.3.2")]
    expect(out).to include(<<-E.strip).and include("rails-2.3.2 from rubygems remote at #{source_uri}/ has either corrupted API or lockfile dependencies")
Lic::APIResponseMismatchError: Downloading rails-2.3.2 revealed dependencies not in the API or the lockfile (#{deps.map(&:to_s).join(", ")}).
Either installing with `--full-index` or running `lic update rails` should fix the problem.
    E
  end

  it "does not duplicate specs in the lockfile when updating and a dependency is not installed" do
    install_gemfile! <<-G, :artifice => "compact_index"
      source "#{source_uri}" do
        gem "rails"
        gem "activemerchant"
      end
    G
    gem_command! :uninstall, "activemerchant"
    lic! "update rails", :artifice => "compact_index"
    expect(lockfile.scan(/activemerchant \(/).size).to eq(1)
  end
end
