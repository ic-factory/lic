# frozen_string_literal: true

RSpec.describe "command plugins" do
  before do
    build_repo2 do
      build_plugin "command-mah" do |s|
        s.write "plugins.rb", <<-RUBY
          module Mah
            class Plugin < Lic::Plugin::API
              command "mahcommand" # declares the command

              def exec(command, args)
                puts "MahHello"
              end
            end
          end
        RUBY
      end
    end

    lic "plugin install command-mah --source file://#{gem_repo2}"
  end

  it "executes without arguments" do
    expect(out).to include("Installed plugin command-mah")

    lic "mahcommand"
    expect(out).to eq("MahHello")
  end

  it "accepts the arguments" do
    build_repo2 do
      build_plugin "the-echoer" do |s|
        s.write "plugins.rb", <<-RUBY
          module Resonance
            class Echoer
              # Another method to declare the command
              Lic::Plugin::API.command "echo", self

              def exec(command, args)
                puts "You gave me \#{args.join(", ")}"
              end
            end
          end
        RUBY
      end
    end

    lic "plugin install the-echoer --source file://#{gem_repo2}"
    expect(out).to include("Installed plugin the-echoer")

    lic "echo tacos tofu lasange"
    expect(out).to eq("You gave me tacos, tofu, lasange")
  end

  it "raises error on redeclaration of command" do
    build_repo2 do
      build_plugin "copycat" do |s|
        s.write "plugins.rb", <<-RUBY
          module CopyCat
            class Cheater < Lic::Plugin::API
              command "mahcommand", self

              def exec(command, args)
              end
            end
          end
        RUBY
      end
    end

    lic "plugin install copycat --source file://#{gem_repo2}"

    expect(out).not_to include("Installed plugin copycat")

    expect(out).to include("Failed to install plugin")

    expect(out).to include("Command(s) `mahcommand` declared by copycat are already registered.")
  end
end
