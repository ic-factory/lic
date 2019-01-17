# frozen_string_literal: true

RSpec.describe "lic inject", :lic => "< 2" do
  before :each do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G
  end

  context "without a lockfile" do
    it "locks with the injected gems" do
      expect(licd_app("Gemfile.lock")).not_to exist
      lic "inject 'rack-obama' '> 0'"
      expect(licd_app("Gemfile.lock").read).to match(/rack-obama/)
    end
  end

  context "with a lockfile" do
    before do
      lic "install"
    end

    it "adds the injected gems to the Gemfile" do
      expect(licd_app("Gemfile").read).not_to match(/rack-obama/)
      lic "inject 'rack-obama' '> 0'"
      expect(licd_app("Gemfile").read).to match(/rack-obama/)
    end

    it "locks with the injected gems" do
      expect(licd_app("Gemfile.lock").read).not_to match(/rack-obama/)
      lic "inject 'rack-obama' '> 0'"
      expect(licd_app("Gemfile.lock").read).to match(/rack-obama/)
    end
  end

  context "with injected gems already in the Gemfile" do
    it "doesn't add existing gems" do
      lic "inject 'rack' '> 0'"
      expect(out).to match(/cannot specify the same gem twice/i)
    end
  end

  context "incorrect arguments" do
    it "fails when more than 2 arguments are passed" do
      lic "inject gem_name 1 v"
      expect(out).to eq(<<-E.strip)
ERROR: "lic inject" was called with arguments ["gem_name", "1", "v"]
Usage: "lic inject GEM VERSION"
      E
    end
  end

  context "with source option" do
    it "add gem with source option in gemfile" do
      lic "inject 'foo' '>0' --source file://#{gem_repo1}"
      gemfile = licd_app("Gemfile").read
      str = "gem \"foo\", \"> 0\", :source => \"file://#{gem_repo1}\""
      expect(gemfile).to include str
    end
  end

  context "with group option" do
    it "add gem with group option in gemfile" do
      lic "inject 'rack-obama' '>0' --group=development"
      gemfile = licd_app("Gemfile").read
      str = "gem \"rack-obama\", \"> 0\", :group => :development"
      expect(gemfile).to include str
    end

    it "add gem with multiple groups in gemfile" do
      lic "inject 'rack-obama' '>0' --group=development,test"
      gemfile = licd_app("Gemfile").read
      str = "gem \"rack-obama\", \"> 0\", :groups => [:development, :test]"
      expect(gemfile).to include str
    end
  end

  context "when frozen" do
    before do
      lic "install"
      if Lic.feature_flag.lic_2_mode?
        lic! "config --local deployment true"
      else
        lic! "config --local frozen true"
      end
    end

    it "injects anyway" do
      lic "inject 'rack-obama' '> 0'"
      expect(licd_app("Gemfile").read).to match(/rack-obama/)
    end

    it "locks with the injected gems" do
      expect(licd_app("Gemfile.lock").read).not_to match(/rack-obama/)
      lic "inject 'rack-obama' '> 0'"
      expect(licd_app("Gemfile.lock").read).to match(/rack-obama/)
    end

    it "restores frozen afterwards" do
      lic "inject 'rack-obama' '> 0'"
      config = YAML.load(licd_app(".lic/config").read)
      expect(config["LIC_DEPLOYMENT"] || config["LIC_FROZEN"]).to eq("true")
    end

    it "doesn't allow Gemfile changes" do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack-obama"
      G
      lic "inject 'rack' '> 0'"
      expect(out).to match(/trying to install in deployment mode after changing/)

      expect(licd_app("Gemfile.lock").read).not_to match(/rack-obama/)
    end
  end
end
