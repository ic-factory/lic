# frozen_string_literal: true

RSpec.describe "lic clean" do
  def should_have_gems(*gems)
    gems.each do |g|
      expect(vendored_gems("gems/#{g}")).to exist
      expect(vendored_gems("specifications/#{g}.gemspec")).to exist
      expect(vendored_gems("cache/#{g}.gem")).to exist
    end
  end

  def should_not_have_gems(*gems)
    gems.each do |g|
      expect(vendored_gems("gems/#{g}")).not_to exist
      expect(vendored_gems("specifications/#{g}.gemspec")).not_to exist
      expect(vendored_gems("cache/#{g}.gem")).not_to exist
    end
  end

  it "removes unused gems that are different" do
    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "thin"
      gem "foo"
    G

    lic! "install", forgotten_command_line_options(:path => "vendor/lic", :clean => false)

    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "thin"
    G
    lic! "install"

    lic! :clean

    expect(out).to include("Removing foo (1.0)")

    should_have_gems "thin-1.0", "rack-1.0.0"
    should_not_have_gems "foo-1.0"

    expect(vendored_gems("bin/rackup")).to exist
  end

  it "removes old version of gem if unused" do
    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "rack", "0.9.1"
      gem "foo"
    G

    lic "install", forgotten_command_line_options(:path => "vendor/lic", :clean => false)

    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "rack", "1.0.0"
      gem "foo"
    G
    lic "install"

    lic :clean

    expect(out).to include("Removing rack (0.9.1)")

    should_have_gems "foo-1.0", "rack-1.0.0"
    should_not_have_gems "rack-0.9.1"

    expect(vendored_gems("bin/rackup")).to exist
  end

  it "removes new version of gem if unused" do
    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "rack", "1.0.0"
      gem "foo"
    G

    lic! "install", forgotten_command_line_options(:path => "vendor/lic", :clean => false)

    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "rack", "0.9.1"
      gem "foo"
    G
    lic! "update rack"

    lic! :clean

    expect(out).to include("Removing rack (1.0.0)")

    should_have_gems "foo-1.0", "rack-0.9.1"
    should_not_have_gems "rack-1.0.0"

    expect(vendored_gems("bin/rackup")).to exist
  end

  it "removes gems in lic without groups" do
    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "foo"

      group :test_group do
        gem "rack", "1.0.0"
      end
    G

    lic "install", forgotten_command_line_options(:path => "vendor/lic")
    lic "install", forgotten_command_line_options(:without => "test_group")
    lic :clean

    expect(out).to include("Removing rack (1.0.0)")

    should_have_gems "foo-1.0"
    should_not_have_gems "rack-1.0.0"

    expect(vendored_gems("bin/rackup")).to_not exist
  end

  it "does not remove cached git dir if it's being used" do
    build_git "foo"
    revision = revision_for(lib_path("foo-1.0"))
    git_path = lib_path("foo-1.0")

    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "rack", "1.0.0"
      git "#{git_path}", :ref => "#{revision}" do
        gem "foo"
      end
    G

    lic "install", forgotten_command_line_options(:path => "vendor/lic")

    lic :clean

    digest = Digest(:SHA1).hexdigest(git_path.to_s)
    cache_path = Lic::VERSION.start_with?("1.") ? vendored_gems("cache/lic/git/foo-1.0-#{digest}") : home(".lic/cache/git/foo-1.0-#{digest}")
    expect(cache_path).to exist
  end

  it "removes unused git gems" do
    build_git "foo", :path => lib_path("foo")
    git_path = lib_path("foo")
    revision = revision_for(git_path)

    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "rack", "1.0.0"
      git "#{git_path}", :ref => "#{revision}" do
        gem "foo"
      end
    G

    lic "install", forgotten_command_line_options(:path => "vendor/lic")

    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "rack", "1.0.0"
    G
    lic "install"

    lic :clean

    expect(out).to include("Removing foo (#{revision[0..11]})")

    expect(vendored_gems("gems/rack-1.0.0")).to exist
    expect(vendored_gems("lic/gems/foo-#{revision[0..11]}")).not_to exist
    digest = Digest(:SHA1).hexdigest(git_path.to_s)
    expect(vendored_gems("cache/lic/git/foo-#{digest}")).not_to exist

    expect(vendored_gems("specifications/rack-1.0.0.gemspec")).to exist

    expect(vendored_gems("bin/rackup")).to exist
  end

  it "removes old git gems" do
    build_git "foo-bar", :path => lib_path("foo-bar")
    revision = revision_for(lib_path("foo-bar"))

    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "rack", "1.0.0"
      git "#{lib_path("foo-bar")}" do
        gem "foo-bar"
      end
    G

    lic! "install", forgotten_command_line_options(:path => "vendor/lic")

    update_git "foo", :path => lib_path("foo-bar")
    revision2 = revision_for(lib_path("foo-bar"))

    lic! "update", :all => lic_update_requires_all?
    lic! :clean

    expect(out).to include("Removing foo-bar (#{revision[0..11]})")

    expect(vendored_gems("gems/rack-1.0.0")).to exist
    expect(vendored_gems("lic/gems/foo-bar-#{revision[0..11]}")).not_to exist
    expect(vendored_gems("lic/gems/foo-bar-#{revision2[0..11]}")).to exist

    expect(vendored_gems("specifications/rack-1.0.0.gemspec")).to exist

    expect(vendored_gems("bin/rackup")).to exist
  end

  it "does not remove nested gems in a git repo" do
    build_lib "activesupport", "3.0", :path => lib_path("rails/activesupport")
    build_git "rails", "3.0", :path => lib_path("rails") do |s|
      s.add_dependency "activesupport", "= 3.0"
    end
    revision = revision_for(lib_path("rails"))

    gemfile <<-G
      gem "activesupport", :git => "#{lib_path("rails")}", :ref => '#{revision}'
    G

    lic "install", forgotten_command_line_options(:path => "vendor/lic")
    lic :clean
    expect(out).to include("")

    expect(vendored_gems("lic/gems/rails-#{revision[0..11]}")).to exist
  end

  it "does not remove git sources that are in without groups" do
    build_git "foo", :path => lib_path("foo")
    git_path = lib_path("foo")
    revision = revision_for(git_path)

    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "rack", "1.0.0"
      group :test do
        git "#{git_path}", :ref => "#{revision}" do
          gem "foo"
        end
      end
    G
    lic "install", forgotten_command_line_options(:path => "vendor/lic", :without => "test")

    lic :clean

    expect(out).to include("")
    expect(vendored_gems("lic/gems/foo-#{revision[0..11]}")).to exist
    digest = Digest(:SHA1).hexdigest(git_path.to_s)
    expect(vendored_gems("cache/lic/git/foo-#{digest}")).to_not exist
  end

  it "does not blow up when using without groups" do
    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "rack"

      group :development do
        gem "foo"
      end
    G

    lic "install", forgotten_command_line_options(:path => "vendor/lic", :without => "development")

    lic :clean
    expect(exitstatus).to eq(0) if exitstatus
  end

  it "displays an error when used without --path" do
    lic! "config path.system true"
    install_gemfile <<-G
      source "file://#{gem_repo1}"

      gem "rack", "1.0.0"
    G

    lic :clean

    expect(exitstatus).to eq(15) if exitstatus
    expect(out).to include("--force")
  end

  # handling lic clean upgrade path from the pre's
  it "removes .gem/.gemspec file even if there's no corresponding gem dir" do
    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "thin"
      gem "foo"
    G

    lic "install", forgotten_command_line_options(:path => "vendor/lic")

    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "foo"
    G
    lic "install"

    FileUtils.rm(vendored_gems("bin/rackup"))
    FileUtils.rm_rf(vendored_gems("gems/thin-1.0"))
    FileUtils.rm_rf(vendored_gems("gems/rack-1.0.0"))

    lic :clean

    should_not_have_gems "thin-1.0", "rack-1.0"
    should_have_gems "foo-1.0"

    expect(vendored_gems("bin/rackup")).not_to exist
  end

  it "does not call clean automatically when using system gems" do
    lic! "config path.system true"

    lic! :config

    install_gemfile! <<-G
      source "file://#{gem_repo1}"

      gem "thin"
      gem "rack"
    G

    lic! "info thin"

    install_gemfile! <<-G
      source "file://#{gem_repo1}"

      gem "rack"
    G

    sys_exec! "gem list"
    expect(out).to include("rack (1.0.0)").and include("thin (1.0)")
  end

  it "--clean should override the lic setting on install", :lic => "< 2" do
    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "thin"
      gem "rack"
    G
    lic "install", forgotten_command_line_options(:path => "vendor/lic", :clean => true)

    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "rack"
    G
    lic "install"

    should_have_gems "rack-1.0.0"
    should_not_have_gems "thin-1.0"
  end

  it "--clean should override the lic setting on update", :lic => "< 2" do
    build_repo2

    gemfile <<-G
      source "file://#{gem_repo2}"

      gem "foo"
    G
    lic! "install", forgotten_command_line_options(:path => "vendor/lic", :clean => true)

    update_repo2 do
      build_gem "foo", "1.0.1"
    end

    lic! "update", :all => lic_update_requires_all?

    should_have_gems "foo-1.0.1"
    should_not_have_gems "foo-1.0"
  end

  it "automatically cleans when path has not been set", :lic => "2" do
    build_repo2

    install_gemfile! <<-G
      source "file://#{gem_repo2}"

      gem "foo"
    G

    update_repo2 do
      build_gem "foo", "1.0.1"
    end

    lic! "update", :all => true

    files = Pathname.glob(licd_app(".lic", Lic.ruby_scope, "*", "*"))
    files.map! {|f| f.to_s.sub(licd_app(".lic", Lic.ruby_scope).to_s, "") }
    expect(files.sort).to eq %w[
      /cache/foo-1.0.1.gem
      /gems/foo-1.0.1
      /specifications/foo-1.0.1.gemspec
    ]
  end

  it "does not clean automatically on --path" do
    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "thin"
      gem "rack"
    G
    lic "install", forgotten_command_line_options(:path => "vendor/lic")

    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "rack"
    G
    lic "install"

    should_have_gems "rack-1.0.0", "thin-1.0"
  end

  it "does not clean on lic update with --path" do
    build_repo2

    gemfile <<-G
      source "file://#{gem_repo2}"

      gem "foo"
    G
    lic! "install", forgotten_command_line_options(:path => "vendor/lic")

    update_repo2 do
      build_gem "foo", "1.0.1"
    end

    lic! :update, :all => lic_update_requires_all?
    should_have_gems "foo-1.0", "foo-1.0.1"
  end

  it "does not clean on lic update when using --system" do
    lic! "config path.system true"

    build_repo2

    gemfile <<-G
      source "file://#{gem_repo2}"

      gem "foo"
    G
    lic! "install"

    update_repo2 do
      build_gem "foo", "1.0.1"
    end
    lic! :update, :all => lic_update_requires_all?

    sys_exec! "gem list"
    expect(out).to include("foo (1.0.1, 1.0)")
  end

  it "cleans system gems when --force is used" do
    lic! "config path.system true"

    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "foo"
      gem "rack"
    G
    lic :install

    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "rack"
    G
    lic :install
    lic "clean --force"

    expect(out).to include("Removing foo (1.0)")
    sys_exec "gem list"
    expect(out).not_to include("foo (1.0)")
    expect(out).to include("rack (1.0.0)")
  end

  describe "when missing permissions" do
    before { ENV["LIC_PATH__SYSTEM"] = "true" }
    let(:system_cache_path) { system_gem_path("cache") }
    after do
      FileUtils.chmod(0o755, system_cache_path)
    end
    it "returns a helpful error message" do
      gemfile <<-G
        source "file://#{gem_repo1}"

        gem "foo"
        gem "rack"
      G
      lic :install

      gemfile <<-G
        source "file://#{gem_repo1}"

        gem "rack"
      G
      lic :install

      FileUtils.chmod(0o500, system_cache_path)

      lic :clean, :force => true

      expect(out).to include(system_gem_path.to_s)
      expect(out).to include("grant write permissions")

      sys_exec "gem list"
      expect(out).to include("foo (1.0)")
      expect(out).to include("rack (1.0.0)")
    end
  end

  it "cleans git gems with a 7 length git revision" do
    build_git "foo"
    revision = revision_for(lib_path("foo-1.0"))

    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "foo", :git => "#{lib_path("foo-1.0")}"
    G

    lic "install", forgotten_command_line_options(:path => "vendor/lic")

    # mimic 7 length git revisions in Gemfile.lock
    gemfile_lock = File.read(licd_app("Gemfile.lock")).split("\n")
    gemfile_lock.each_with_index do |line, index|
      gemfile_lock[index] = line[0..(11 + 7)] if line.include?("  revision:")
    end
    File.open(licd_app("Gemfile.lock"), "w") do |file|
      file.print gemfile_lock.join("\n")
    end

    lic "install", forgotten_command_line_options(:path => "vendor/lic")

    lic :clean

    expect(out).not_to include("Removing foo (1.0 #{revision[0..6]})")

    expect(vendored_gems("lic/gems/foo-1.0-#{revision[0..6]}")).to exist
  end

  it "when using --force on system gems, it doesn't remove binaries" do
    lic! "config path.system true"

    build_repo2
    update_repo2 do
      build_gem "bindir" do |s|
        s.bindir = "exe"
        s.executables = "foo"
      end
    end

    gemfile <<-G
      source "file://#{gem_repo2}"

      gem "bindir"
    G
    lic :install

    lic "clean --force"

    sys_exec "foo"

    expect(exitstatus).to eq(0) if exitstatus
    expect(out).to eq("1.0")
  end

  it "doesn't blow up on path gems without a .gempsec" do
    relative_path = "vendor/private_gems/bar-1.0"
    absolute_path = licd_app(relative_path)
    FileUtils.mkdir_p("#{absolute_path}/lib/bar")
    File.open("#{absolute_path}/lib/bar/bar.rb", "wb") do |file|
      file.puts "module Bar; end"
    end

    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "foo"
      gem "bar", "1.0", :path => "#{relative_path}"
    G

    lic "install", forgotten_command_line_options(:path => "vendor/lic")
    lic! :clean
  end

  it "doesn't remove gems in dry-run mode with path set" do
    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "thin"
      gem "foo"
    G

    lic "install", forgotten_command_line_options(:path => "vendor/lic", :clean => false)

    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "thin"
    G

    lic :install

    lic "clean --dry-run"

    expect(out).not_to include("Removing foo (1.0)")
    expect(out).to include("Would have removed foo (1.0)")

    should_have_gems "thin-1.0", "rack-1.0.0", "foo-1.0"

    expect(vendored_gems("bin/rackup")).to exist
  end

  it "doesn't remove gems in dry-run mode with no path set" do
    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "thin"
      gem "foo"
    G

    lic "install", forgotten_command_line_options(:path => "vendor/lic", :clean => false)

    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "thin"
    G

    lic :install

    lic "configuration --delete path"

    lic "clean --dry-run"

    expect(out).not_to include("Removing foo (1.0)")
    expect(out).to include("Would have removed foo (1.0)")

    should_have_gems "thin-1.0", "rack-1.0.0", "foo-1.0"

    expect(vendored_gems("bin/rackup")).to exist
  end

  it "doesn't store dry run as a config setting" do
    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "thin"
      gem "foo"
    G

    lic "install", forgotten_command_line_options(:path => "vendor/lic", :clean => false)
    lic "config dry_run false"

    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "thin"
    G

    lic :install

    lic "clean"

    expect(out).to include("Removing foo (1.0)")
    expect(out).not_to include("Would have removed foo (1.0)")

    should_have_gems "thin-1.0", "rack-1.0.0"
    should_not_have_gems "foo-1.0"

    expect(vendored_gems("bin/rackup")).to exist
  end

  it "performs an automatic lic install" do
    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "thin"
      gem "foo"
    G

    lic! "install", forgotten_command_line_options(:path => "vendor/lic", :clean => false)

    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "thin"
      gem "weakling"
    G

    lic! "config auto_install 1"
    lic! :clean
    expect(out).to include("Installing weakling 0.0.3")
    should_have_gems "thin-1.0", "rack-1.0.0", "weakling-0.0.3"
    should_not_have_gems "foo-1.0"
  end

  it "doesn't remove extensions artifacts from licd git gems after clean", :ruby_repo, :rubygems => "2.2" do
    build_git "very_simple_git_binary", &:add_c_extension

    revision = revision_for(lib_path("very_simple_git_binary-1.0"))

    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "very_simple_git_binary", :git => "#{lib_path("very_simple_git_binary-1.0")}", :ref => "#{revision}"
    G

    lic! "install", forgotten_command_line_options(:path => "vendor/lic")
    expect(vendored_gems("lic/gems/extensions")).to exist
    expect(vendored_gems("lic/gems/very_simple_git_binary-1.0-#{revision[0..11]}")).to exist

    lic! :clean
    expect(out).to eq("")

    expect(vendored_gems("lic/gems/extensions")).to exist
    expect(vendored_gems("lic/gems/very_simple_git_binary-1.0-#{revision[0..11]}")).to exist
  end

  it "removes extension directories", :ruby_repo, :rubygems => "2.2" do
    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "thin"
      gem "very_simple_binary"
      gem "simple_binary"
    G

    lic! "install", forgotten_command_line_options(:path => "vendor/lic")

    very_simple_binary_extensions_dir =
      Pathname.glob("#{vendored_gems}/extensions/*/*/very_simple_binary-1.0").first

    simple_binary_extensions_dir =
      Pathname.glob("#{vendored_gems}/extensions/*/*/simple_binary-1.0").first

    expect(very_simple_binary_extensions_dir).to exist
    expect(simple_binary_extensions_dir).to exist

    gemfile <<-G
      source "file://#{gem_repo1}"

      gem "thin"
      gem "simple_binary"
    G

    lic! "install"
    lic! :clean
    expect(out).to eq("Removing very_simple_binary (1.0)")

    expect(very_simple_binary_extensions_dir).not_to exist
    expect(simple_binary_extensions_dir).to exist
  end
end
