# frozen_string_literal: true

RSpec.describe "lic install" do
  context "with gem sources" do
    context "when gems include post install messages" do
      it "should display the post-install messages after installing" do
        gemfile <<-G
          source "file://#{gem_repo1}"
          gem 'rack'
          gem 'thin'
          gem 'rack-obama'
        G

        lic :install
        expect(out).to include("Post-install message from rack:")
        expect(out).to include("Rack's post install message")
        expect(out).to include("Post-install message from thin:")
        expect(out).to include("Thin's post install message")
        expect(out).to include("Post-install message from rack-obama:")
        expect(out).to include("Rack-obama's post install message")
      end
    end

    context "when gems do not include post install messages" do
      it "should not display any post-install messages" do
        gemfile <<-G
          source "file://#{gem_repo1}"
          gem "activesupport"
        G

        lic :install
        expect(out).not_to include("Post-install message")
      end
    end

    context "when a dependecy includes a post install message" do
      it "should display the post install message" do
        gemfile <<-G
          source "file://#{gem_repo1}"
          gem 'rack_middleware'
        G

        lic :install
        expect(out).to include("Post-install message from rack:")
        expect(out).to include("Rack's post install message")
      end
    end
  end

  context "with git sources" do
    context "when gems include post install messages" do
      it "should display the post-install messages after installing" do
        build_git "foo" do |s|
          s.post_install_message = "Foo's post install message"
        end
        gemfile <<-G
          source "file://#{gem_repo1}"
          gem 'foo', :git => '#{lib_path("foo-1.0")}'
        G

        lic :install
        expect(out).to include("Post-install message from foo:")
        expect(out).to include("Foo's post install message")
      end

      it "should display the post-install messages if repo is updated" do
        build_git "foo" do |s|
          s.post_install_message = "Foo's post install message"
        end
        gemfile <<-G
          source "file://#{gem_repo1}"
          gem 'foo', :git => '#{lib_path("foo-1.0")}'
        G
        lic :install

        build_git "foo", "1.1" do |s|
          s.post_install_message = "Foo's 1.1 post install message"
        end
        gemfile <<-G
          source "file://#{gem_repo1}"
          gem 'foo', :git => '#{lib_path("foo-1.1")}'
        G
        lic :install

        expect(out).to include("Post-install message from foo:")
        expect(out).to include("Foo's 1.1 post install message")
      end

      it "should not display the post-install messages if repo is not updated" do
        build_git "foo" do |s|
          s.post_install_message = "Foo's post install message"
        end
        gemfile <<-G
          source "file://#{gem_repo1}"
          gem 'foo', :git => '#{lib_path("foo-1.0")}'
        G

        lic :install
        expect(out).to include("Post-install message from foo:")
        expect(out).to include("Foo's post install message")

        lic :install
        expect(out).not_to include("Post-install message")
      end
    end

    context "when gems do not include post install messages" do
      it "should not display any post-install messages" do
        build_git "foo" do |s|
          s.post_install_message = nil
        end
        gemfile <<-G
          source "file://#{gem_repo1}"
          gem 'foo', :git => '#{lib_path("foo-1.0")}'
        G

        lic :install
        expect(out).not_to include("Post-install message")
      end
    end
  end

  context "when ignore post-install messages for gem is set" do
    it "doesn't display any post-install messages" do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G

      lic "config ignore_messages.rack true"

      lic :install
      expect(out).not_to include("Post-install message")
    end
  end

  context "when ignore post-install messages for all gems" do
    it "doesn't display any post-install messages" do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G

      lic "config ignore_messages true"

      lic :install
      expect(out).not_to include("Post-install message")
    end
  end
end
