# frozen_string_literal: true

RSpec.describe "lic init" do
  it "generates a Gemfile", :lic => "< 2" do
    lic! :init
    expect(out).to include("Writing new Gemfile")
    expect(licd_app("Gemfile")).to be_file
  end

  it "generates a gems.rb", :lic => "2" do
    lic! :init
    expect(out).to include("Writing new gems.rb")
    expect(licd_app("gems.rb")).to be_file
  end

  context "when a Gemfile already exists", :lic => "< 2" do
    before do
      create_file "Gemfile", <<-G
        gem "rails"
      G
    end

    it "does not change existing Gemfiles" do
      expect { lic :init }.not_to change { File.read(licd_app("Gemfile")) }
    end

    it "notifies the user that an existing Gemfile already exists" do
      lic :init
      expect(out).to include("Gemfile already exists")
    end
  end

  context "when gems.rb already exists", :lic => ">= 2" do
    before do
      create_file("gems.rb", <<-G)
        gem "rails"
      G
    end

    it "does not change existing Gemfiles" do
      expect { lic :init }.not_to change { File.read(licd_app("gems.rb")) }
    end

    it "notifies the user that an existing gems.rb already exists" do
      lic :init
      expect(out).to include("gems.rb already exists")
    end
  end

  context "when a Gemfile exists in a parent directory", :lic => "< 2" do
    let(:subdir) { "child_dir" }

    it "lets users generate a Gemfile in a child directory" do
      lic! :init

      FileUtils.mkdir licd_app(subdir)

      Dir.chdir licd_app(subdir) do
        lic! :init
      end

      expect(out).to include("Writing new Gemfile")
      expect(licd_app("#{subdir}/Gemfile")).to be_file
    end
  end

  context "when the dir is not writable by the current user" do
    let(:subdir) { "child_dir" }

    it "notifies the user that it can not write to it" do
      FileUtils.mkdir licd_app(subdir)
      # chmod a-w it
      mode = File.stat(licd_app(subdir)).mode ^ 0o222
      FileUtils.chmod mode, licd_app(subdir)

      Dir.chdir licd_app(subdir) do
        lic :init
      end

      expect(out).to include("directory is not writable")
      expect(Dir[licd_app("#{subdir}/*")]).to be_empty
    end
  end

  context "when a gems.rb file exists in a parent directory", :lic => ">= 2" do
    let(:subdir) { "child_dir" }

    it "lets users generate a Gemfile in a child directory" do
      lic! :init

      FileUtils.mkdir licd_app(subdir)

      Dir.chdir licd_app(subdir) do
        lic! :init
      end

      expect(out).to include("Writing new gems.rb")
      expect(licd_app("#{subdir}/gems.rb")).to be_file
    end
  end

  context "given --gemspec option", :lic => "< 2" do
    let(:spec_file) { tmp.join("test.gemspec") }

    it "should generate from an existing gemspec" do
      File.open(spec_file, "w") do |file|
        file << <<-S
          Gem::Specification.new do |s|
          s.name = 'test'
          s.add_dependency 'rack', '= 1.0.1'
          s.add_development_dependency 'rspec', '1.2'
          end
        S
      end

      lic :init, :gemspec => spec_file

      gemfile = if Lic::VERSION[0, 2] == "1."
        licd_app("Gemfile").read
      else
        licd_app("gems.rb").read
      end
      expect(gemfile).to match(%r{source 'https://rubygems.org'})
      expect(gemfile.scan(/gem "rack", "= 1.0.1"/).size).to eq(1)
      expect(gemfile.scan(/gem "rspec", "= 1.2"/).size).to eq(1)
      expect(gemfile.scan(/group :development/).size).to eq(1)
    end

    context "when gemspec file is invalid" do
      it "notifies the user that specification is invalid" do
        File.open(spec_file, "w") do |file|
          file << <<-S
            Gem::Specification.new do |s|
            s.name = 'test'
            s.invalid_method_name
            end
          S
        end

        lic :init, :gemspec => spec_file
        expect(last_command.lic_err).to include("There was an error while loading `test.gemspec`")
      end
    end
  end

  context "when init_gems_rb setting is enabled" do
    before { lic "config init_gems_rb true" }

    context "given --gemspec option", :lic => "< 2" do
      let(:spec_file) { tmp.join("test.gemspec") }

      before do
        File.open(spec_file, "w") do |file|
          file << <<-S
            Gem::Specification.new do |s|
            s.name = 'test'
            s.add_dependency 'rack', '= 1.0.1'
            s.add_development_dependency 'rspec', '1.2'
            end
          S
        end
      end

      it "should generate from an existing gemspec" do
        lic :init, :gemspec => spec_file

        gemfile = licd_app("gems.rb").read
        expect(gemfile).to match(%r{source 'https://rubygems.org'})
        expect(gemfile.scan(/gem "rack", "= 1.0.1"/).size).to eq(1)
        expect(gemfile.scan(/gem "rspec", "= 1.2"/).size).to eq(1)
        expect(gemfile.scan(/group :development/).size).to eq(1)
      end

      it "prints message to user" do
        lic :init, :gemspec => spec_file

        expect(out).to include("Writing new gems.rb")
      end
    end
  end
end
