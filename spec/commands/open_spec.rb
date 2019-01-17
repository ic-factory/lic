# frozen_string_literal: true

RSpec.describe "lic open" do
  before :each do
    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rails"
    G
  end

  it "opens the gem with LIC_EDITOR as highest priority" do
    lic "open rails", :env => { "EDITOR" => "echo editor", "VISUAL" => "echo visual", "LIC_EDITOR" => "echo lic_editor" }
    expect(out).to include("lic_editor #{default_lic_path("gems", "rails-2.3.2")}")
  end

  it "opens the gem with VISUAL as 2nd highest priority" do
    lic "open rails", :env => { "EDITOR" => "echo editor", "VISUAL" => "echo visual", "LIC_EDITOR" => "" }
    expect(out).to include("visual #{default_lic_path("gems", "rails-2.3.2")}")
  end

  it "opens the gem with EDITOR as 3rd highest priority" do
    lic "open rails", :env => { "EDITOR" => "echo editor", "VISUAL" => "", "LIC_EDITOR" => "" }
    expect(out).to include("editor #{default_lic_path("gems", "rails-2.3.2")}")
  end

  it "complains if no EDITOR is set" do
    lic "open rails", :env => { "EDITOR" => "", "VISUAL" => "", "LIC_EDITOR" => "" }
    expect(out).to eq("To open a licd gem, set $EDITOR or $LIC_EDITOR")
  end

  it "complains if gem not in lic" do
    lic "open missing", :env => { "EDITOR" => "echo editor", "VISUAL" => "", "LIC_EDITOR" => "" }
    expect(out).to match(/could not find gem 'missing'/i)
  end

  it "does not blow up if the gem to open does not have a Gemfile" do
    git = build_git "foo"
    ref = git.ref_for("master", 11)

    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem 'foo', :git => "#{lib_path("foo-1.0")}"
    G

    lic "open foo", :env => { "EDITOR" => "echo editor", "VISUAL" => "", "LIC_EDITOR" => "" }
    expect(out).to match("editor #{default_lic_path.join("lic/gems/foo-1.0-#{ref}")}")
  end

  it "suggests alternatives for similar-sounding gems" do
    lic "open Rails", :env => { "EDITOR" => "echo editor", "VISUAL" => "", "LIC_EDITOR" => "" }
    expect(out).to match(/did you mean rails\?/i)
  end

  it "opens the gem with short words" do
    lic "open rec", :env => { "EDITOR" => "echo editor", "VISUAL" => "echo visual", "LIC_EDITOR" => "echo lic_editor" }

    expect(out).to include("lic_editor #{default_lic_path("gems", "activerecord-2.3.2")}")
  end

  it "select the gem from many match gems" do
    env = { "EDITOR" => "echo editor", "VISUAL" => "echo visual", "LIC_EDITOR" => "echo lic_editor" }
    lic "open active", :env => env do |input, _, _|
      input.puts "2"
    end

    expect(out).to match(/lic_editor #{default_lic_path('gems', 'activerecord-2.3.2')}\z/)
  end

  it "allows selecting exit from many match gems" do
    env = { "EDITOR" => "echo editor", "VISUAL" => "echo visual", "LIC_EDITOR" => "echo lic_editor" }
    lic! "open active", :env => env do |input, _, _|
      input.puts "0"
    end
  end

  it "performs an automatic lic install" do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rails"
      gem "foo"
    G

    lic "config auto_install 1"
    lic "open rails", :env => { "EDITOR" => "echo editor", "VISUAL" => "", "LIC_EDITOR" => "" }
    expect(out).to include("Installing foo 1.0")
  end

  it "opens the editor with a clean env" do
    lic "open", :env => { "EDITOR" => "sh -c 'env'", "VISUAL" => "", "LIC_EDITOR" => "" }
    expect(out).not_to include("LIC_GEMFILE=")
  end
end
