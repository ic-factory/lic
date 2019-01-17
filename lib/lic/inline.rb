# frozen_string_literal: true

require "lic/compatibility_guard"

# Allows for declaring a Gemfile inline in a ruby script, optionally installing
# any gems that aren't already installed on the user's system.
#
# @note Every gem that is specified in this 'Gemfile' will be `require`d, as if
#       the user had manually called `Lic.require`. To avoid a requested gem
#       being automatically required, add the `:require => false` option to the
#       `gem` dependency declaration.
#
# @param install [Boolean] whether gems that aren't already installed on the
#                          user's system should be installed.
#                          Defaults to `false`.
#
# @param gemfile [Proc]    a block that is evaluated as a `Gemfile`.
#
# @example Using an inline Gemfile
#
#          #!/usr/bin/env ruby
#
#          require 'lic/inline'
#
#          gemfile do
#            source 'https://rubygems.org'
#            gem 'json', require: false
#            gem 'nap', require: 'rest'
#            gem 'cocoapods', '~> 0.34.1'
#          end
#
#          puts Pod::VERSION # => "0.34.4"
#
def gemfile(install = false, options = {}, &gemfile)
  require "lic"

  opts = options.dup
  ui = opts.delete(:ui) { Lic::UI::Shell.new }
  ui.level = "silent" if opts.delete(:quiet)
  raise ArgumentError, "Unknown options: #{opts.keys.join(", ")}" unless opts.empty?

  old_root = Lic.method(:root)
  def Lic.root
    Lic::SharedHelpers.pwd.expand_path
  end
  Lic::SharedHelpers.set_env "LIC_GEMFILE", "Gemfile"

  Lic::Plugin.gemfile_install(&gemfile) if Lic.feature_flag.plugins?
  builder = Lic::Dsl.new
  builder.instance_eval(&gemfile)

  definition = builder.to_definition(nil, true)
  def definition.lock(*); end
  definition.validate_runtime!

  missing_specs = proc do
    definition.missing_specs?
  end

  Lic.ui = ui if install
  if install || missing_specs.call
    Lic.settings.temporary(:inline => true) do
      installer = Lic::Installer.install(Lic.root, definition, :system => true)
      installer.post_install_messages.each do |name, message|
        Lic.ui.info "Post-install message from #{name}:\n#{message}"
      end
    end
  end

  runtime = Lic::Runtime.new(nil, definition)
  runtime.setup.require
ensure
  lic_module = class << Lic; self; end
  lic_module.send(:define_method, :root, old_root) if old_root
end
