# frozen_string_literal: true

RSpec.describe "lic lock" do
  def strip_lockfile(lockfile)
    strip_whitespace(lockfile).sub(/\n\Z/, "")
  end

  def read_lockfile(file = "Gemfile.lock")
    strip_lockfile licd_app(file).read
  end

  let(:repo) { gem_repo1 }

  before :each do
    gemfile <<-G
      source "file://localhost#{repo}"
      gem "rails"
      gem "with_license"
      gem "foo"
    G

    @lockfile = strip_lockfile(normalize_uri_file(<<-L))
      GEM
        remote: file://localhost#{repo}/
        specs:
          actionmailer (2.3.2)
            activesupport (= 2.3.2)
          actionpack (2.3.2)
            activesupport (= 2.3.2)
          activerecord (2.3.2)
            activesupport (= 2.3.2)
          activeresource (2.3.2)
            activesupport (= 2.3.2)
          activesupport (2.3.2)
          foo (1.0)
          rails (2.3.2)
            actionmailer (= 2.3.2)
            actionpack (= 2.3.2)
            activerecord (= 2.3.2)
            activeresource (= 2.3.2)
            rake (= 10.0.2)
          rake (10.0.2)
          with_license (1.0)

      PLATFORMS
        #{lockfile_platforms}

      DEPENDENCIES
        foo
        rails
        with_license

      LICD WITH
         #{Lic::VERSION}
    L
  end

  it "prints a lockfile when there is no existing lockfile with --print" do
    lic "lock --print"

    expect(out).to eq(@lockfile)
  end

  it "prints a lockfile when there is an existing lockfile with --print" do
    lockfile @lockfile

    lic "lock --print"

    expect(out).to eq(@lockfile)
  end

  it "writes a lockfile when there is no existing lockfile" do
    lic "lock"

    expect(read_lockfile).to eq(@lockfile)
  end

  it "writes a lockfile when there is an outdated lockfile using --update" do
    lockfile @lockfile.gsub("2.3.2", "2.3.1")

    lic! "lock --update"

    expect(read_lockfile).to eq(@lockfile)
  end

  it "does not fetch remote specs when using the --local option" do
    lic "lock --update --local"

    expect(out).to match(/sources listed in your Gemfile|installed locally/)
  end

  it "works with --gemfile flag" do
    create_file "CustomGemfile", <<-G
      source "file://localhost#{repo}"
      gem "foo"
    G
    lockfile = strip_lockfile(normalize_uri_file(<<-L))
      GEM
        remote: file://localhost#{repo}/
        specs:
          foo (1.0)

      PLATFORMS
        #{lockfile_platforms}

      DEPENDENCIES
        foo

      LICD WITH
         #{Lic::VERSION}
    L
    lic "lock --gemfile CustomGemfile"

    expect(out).to match(/Writing lockfile to.+CustomGemfile\.lock/)
    expect(read_lockfile("CustomGemfile.lock")).to eq(lockfile)
    expect { read_lockfile }.to raise_error(Errno::ENOENT)
  end

  it "writes to a custom location using --lockfile" do
    lic "lock --lockfile=lock"

    expect(out).to match(/Writing lockfile to.+lock/)
    expect(read_lockfile("lock")).to eq(@lockfile)
    expect { read_lockfile }.to raise_error(Errno::ENOENT)
  end

  it "writes to custom location using --lockfile when a default lockfile is present" do
    lic "install"
    lic "lock --lockfile=lock"

    expect(out).to match(/Writing lockfile to.+lock/)
    expect(read_lockfile("lock")).to eq(@lockfile)
  end

  it "update specific gems using --update" do
    lockfile @lockfile.gsub("2.3.2", "2.3.1").gsub("10.0.2", "10.0.1")

    lic "lock --update rails rake"

    expect(read_lockfile).to eq(@lockfile)
  end

  it "errors when updating a missing specific gems using --update" do
    lockfile @lockfile

    lic "lock --update blahblah"
    expect(out).to eq("Could not find gem 'blahblah'.")

    expect(read_lockfile).to eq(@lockfile)
  end

  it "can lock without downloading gems" do
    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "thin"
      gem "rack_middleware", :group => "test"
    G
    lic! "config set without test"
    lic! "config set path .lic"
    lic! "lock"
    expect(licd_app(".lic")).not_to exist
  end

  # see update_spec for more coverage on same options. logic is shared so it's not necessary
  # to repeat coverage here.
  context "conservative updates" do
    before do
      build_repo4 do
        build_gem "foo", %w[1.4.3 1.4.4] do |s|
          s.add_dependency "bar", "~> 2.0"
        end
        build_gem "foo", %w[1.4.5 1.5.0] do |s|
          s.add_dependency "bar", "~> 2.1"
        end
        build_gem "foo", %w[1.5.1] do |s|
          s.add_dependency "bar", "~> 3.0"
        end
        build_gem "bar", %w[2.0.3 2.0.4 2.0.5 2.1.0 2.1.1 3.0.0]
        build_gem "qux", %w[1.0.0 1.0.1 1.1.0 2.0.0]
      end

      # establish a lockfile set to 1.4.3
      install_gemfile <<-G
        source "file://#{gem_repo4}"
        gem 'foo', '1.4.3'
        gem 'bar', '2.0.3'
        gem 'qux', '1.0.0'
      G

      # remove 1.4.3 requirement and bar altogether
      # to setup update specs below
      gemfile <<-G
        source "file://#{gem_repo4}"
        gem 'foo'
        gem 'qux'
      G
    end

    it "single gem updates dependent gem to minor" do
      lic "lock --update foo --patch"

      expect(the_lic.locked_gems.specs.map(&:full_name)).to eq(%w[foo-1.4.5 bar-2.1.1 qux-1.0.0].sort)
    end

    it "minor preferred with strict" do
      lic "lock --update --minor --strict"

      expect(the_lic.locked_gems.specs.map(&:full_name)).to eq(%w[foo-1.5.0 bar-2.1.1 qux-1.1.0].sort)
    end
  end

  it "supports adding new platforms" do
    lic! "lock --add-platform java x86-mingw32"

    lockfile = Lic::LockfileParser.new(read_lockfile)
    expect(lockfile.platforms).to match_array(local_platforms.unshift(java, mingw).uniq)
  end

  it "supports adding the `ruby` platform" do
    lic! "lock --add-platform ruby"
    lockfile = Lic::LockfileParser.new(read_lockfile)
    expect(lockfile.platforms).to match_array(local_platforms.unshift("ruby").uniq)
  end

  it "warns when adding an unknown platform" do
    lic "lock --add-platform foobarbaz"
    expect(out).to include("The platform `foobarbaz` is unknown to RubyGems and adding it will likely lead to resolution errors")
  end

  it "allows removing platforms" do
    lic! "lock --add-platform java x86-mingw32"

    lockfile = Lic::LockfileParser.new(read_lockfile)
    expect(lockfile.platforms).to match_array(local_platforms.unshift(java, mingw).uniq)

    lic! "lock --remove-platform java"

    lockfile = Lic::LockfileParser.new(read_lockfile)
    expect(lockfile.platforms).to match_array(local_platforms.unshift(mingw).uniq)
  end

  it "errors when removing all platforms" do
    lic "lock --remove-platform #{local_platforms.join(" ")}"
    expect(last_command.lic_err).to include("Removing all platforms from the lic is not allowed")
  end

  # from https://github.com/lic/lic/issues/4896
  it "properly adds platforms when platform requirements come from different dependencies" do
    build_repo4 do
      build_gem "ffi", "1.9.14"
      build_gem "ffi", "1.9.14" do |s|
        s.platform = mingw
      end

      build_gem "gssapi", "0.1"
      build_gem "gssapi", "0.2"
      build_gem "gssapi", "0.3"
      build_gem "gssapi", "1.2.0" do |s|
        s.add_dependency "ffi", ">= 1.0.1"
      end

      build_gem "mixlib-shellout", "2.2.6"
      build_gem "mixlib-shellout", "2.2.6" do |s|
        s.platform = "universal-mingw32"
        s.add_dependency "win32-process", "~> 0.8.2"
      end

      # we need all these versions to get the sorting the same as it would be
      # pulling from rubygems.org
      %w[0.8.3 0.8.2 0.8.1 0.8.0].each do |v|
        build_gem "win32-process", v do |s|
          s.add_dependency "ffi", ">= 1.0.0"
        end
      end
    end

    gemfile <<-G
      source "file://localhost#{gem_repo4}"

      gem "mixlib-shellout"
      gem "gssapi"
    G

    simulate_platform(mingw) { lic! :lock }

    expect(the_lic.lockfile).to read_as(normalize_uri_file(strip_whitespace(<<-G)))
      GEM
        remote: file://localhost#{gem_repo4}/
        specs:
          ffi (1.9.14-x86-mingw32)
          gssapi (1.2.0)
            ffi (>= 1.0.1)
          mixlib-shellout (2.2.6-universal-mingw32)
            win32-process (~> 0.8.2)
          win32-process (0.8.3)
            ffi (>= 1.0.0)

      PLATFORMS
        x86-mingw32

      DEPENDENCIES
        gssapi
        mixlib-shellout

      LICD WITH
         #{Lic::VERSION}
    G

    simulate_platform(rb) { lic! :lock }

    expect(the_lic.lockfile).to read_as(normalize_uri_file(strip_whitespace(<<-G)))
      GEM
        remote: file://localhost#{gem_repo4}/
        specs:
          ffi (1.9.14)
          ffi (1.9.14-x86-mingw32)
          gssapi (1.2.0)
            ffi (>= 1.0.1)
          mixlib-shellout (2.2.6)
          mixlib-shellout (2.2.6-universal-mingw32)
            win32-process (~> 0.8.2)
          win32-process (0.8.3)
            ffi (>= 1.0.0)

      PLATFORMS
        ruby
        x86-mingw32

      DEPENDENCIES
        gssapi
        mixlib-shellout

      LICD WITH
         #{Lic::VERSION}
    G
  end

  context "when an update is available" do
    let(:repo) { gem_repo2 }

    before do
      lockfile(@lockfile)
      build_repo2 do
        build_gem "foo", "2.0"
      end
    end

    it "does not implicitly update" do
      lic! "lock"

      expect(read_lockfile).to eq(@lockfile)
    end

    it "accounts for changes in the gemfile" do
      gemfile gemfile.gsub('"foo"', '"foo", "2.0"')
      lic! "lock"

      expect(read_lockfile).to eq(@lockfile.sub("foo (1.0)", "foo (2.0)").sub(/foo$/, "foo (= 2.0)"))
    end
  end
end
