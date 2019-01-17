# frozen_string_literal: true

RSpec.describe "Lic.with_env helpers" do
  def lic_exec_ruby!(code, *args)
    build_lic_context
    opts = args.last.is_a?(Hash) ? args.pop : {}
    env = opts[:env] ||= {}
    env[:RUBYOPT] ||= "-r#{spec_dir.join("support/hax")}"
    args.push opts
    lic! "exec '#{Gem.ruby}' -e #{code}", *args
  end

  def build_lic_context
    lic "config path vendor/lic"
    gemfile ""
    lic "install"
  end

  describe "Lic.original_env" do
    it "should return the PATH present before lic was activated" do
      code = "print Lic.original_env['PATH']"
      path = `getconf PATH`.strip + "#{File::PATH_SEPARATOR}/foo"
      with_path_as(path) do
        lic_exec_ruby!(code.dump)
        expect(last_command.stdboth).to eq(path)
      end
    end

    it "should return the GEM_PATH present before lic was activated" do
      code = "print Lic.original_env['GEM_PATH']"
      gem_path = ENV["GEM_PATH"] + ":/foo"
      with_gem_path_as(gem_path) do
        lic_exec_ruby!(code.dump)
        expect(last_command.stdboth).to eq(gem_path)
      end
    end

    it "works with nested lic exec invocations", :ruby_repo do
      create_file("exe.rb", <<-'RB')
        count = ARGV.first.to_i
        exit if count < 0
        STDERR.puts "#{count} #{ENV["PATH"].end_with?(":/foo")}"
        if count == 2
          ENV["PATH"] = "#{ENV["PATH"]}:/foo"
        end
        exec(Gem.ruby, __FILE__, (count - 1).to_s)
      RB
      path = `getconf PATH`.strip + File::PATH_SEPARATOR + File.dirname(Gem.ruby)
      with_path_as(path) do
        build_lic_context
        lic! "exec '#{Gem.ruby}' #{licd_app("exe.rb")} 2", :env => { :RUBYOPT => "-r#{spec_dir.join("support/hax")}" }
      end
      expect(err).to eq <<-EOS.strip
2 false
1 true
0 true
      EOS
    end

    it "removes variables that lic added", :ruby_repo do
      original = ruby!('puts ENV.to_a.map {|e| e.join("=") }.sort.join("\n")', :env => { :RUBYOPT => "-r#{spec_dir.join("support/hax")}" })
      code = 'puts Lic.original_env.to_a.map {|e| e.join("=") }.sort.join("\n")'
      lic_exec_ruby! code.dump
      expect(out).to eq original
    end
  end

  shared_examples_for "an unbundling helper" do
    it "should delete LIC_PATH" do
      code = "print #{modified_env}.has_key?('LIC_PATH')"
      ENV["LIC_PATH"] = "./foo"
      lic_exec_ruby! code.dump
      expect(last_command.stdboth).to include "false"
    end

    it "should remove '-rlic/setup' from RUBYOPT" do
      code = "print #{modified_env}['RUBYOPT']"
      ENV["RUBYOPT"] = "-W2 -rlic/setup"
      lic_exec_ruby! code.dump
      expect(last_command.stdboth).not_to include("-rlic/setup")
    end

    it "should clean up RUBYLIB", :ruby_repo do
      code = "print #{modified_env}['RUBYLIB']"
      ENV["RUBYLIB"] = root.join("lib").to_s + File::PATH_SEPARATOR + "/foo"
      lic_exec_ruby! code.dump
      expect(last_command.stdboth).to include("/foo")
    end

    it "should restore the original MANPATH" do
      code = "print #{modified_env}['MANPATH']"
      ENV["MANPATH"] = "/foo"
      ENV["LIC_ORIG_MANPATH"] = "/foo-original"
      lic_exec_ruby! code.dump
      expect(last_command.stdboth).to include("/foo-original")
    end
  end

  describe "Lic.unlicd_env" do
    let(:modified_env) { "Lic.unlicd_env" }

    it_behaves_like "an unbundling helper"
  end

  describe "Lic.clean_env" do
    let(:modified_env) { "Lic.clean_env" }

    it_behaves_like "an unbundling helper"

    it "prints a deprecation", :lic => 2 do
      code = "Lic.clean_env"
      lic_exec_ruby! code.dump
      expect(last_command.stdboth).to include(
        "[DEPRECATED FOR 2.0] `Lic.clean_env` has been deprecated in favor of `Lic.unlicd_env`. " \
        "If you instead want the environment before lic was originally loaded, use `Lic.original_env`"
      )
    end

    it "does not print a deprecation", :lic => "< 2" do
      code = "Lic.clean_env"
      lic_exec_ruby! code.dump
      expect(last_command.stdboth).not_to include(
        "[DEPRECATED FOR 2.0] `Lic.clean_env` has been deprecated in favor of `Lic.unlicd_env`. " \
        "If you instead want the environment before lic was originally loaded, use `Lic.original_env`"
      )
    end
  end

  describe "Lic.with_original_env" do
    it "should set ENV to original_env in the block" do
      expected = Lic.original_env
      actual = Lic.with_original_env { ENV.to_hash }
      expect(actual).to eq(expected)
    end

    it "should restore the environment after execution" do
      Lic.with_original_env do
        ENV["FOO"] = "hello"
      end

      expect(ENV).not_to have_key("FOO")
    end
  end

  describe "Lic.with_clean_env" do
    it "should set ENV to unlicd_env in the block" do
      expected = Lic.unlicd_env
      actual = Lic.with_clean_env { ENV.to_hash }
      expect(actual).to eq(expected)
    end

    it "should restore the environment after execution" do
      Lic.with_clean_env do
        ENV["FOO"] = "hello"
      end

      expect(ENV).not_to have_key("FOO")
    end

    it "prints a deprecation", :lic => 2 do
      code = "Lic.with_clean_env {}"
      lic_exec_ruby! code.dump
      expect(last_command.stdboth).to include(
        "[DEPRECATED FOR 2.0] `Lic.with_clean_env` has been deprecated in favor of `Lic.with_unlicd_env`. " \
        "If you instead want the environment before lic was originally loaded, use `Lic.with_original_env`"
      )
    end

    it "does not print a deprecation", :lic => "< 2" do
      code = "Lic.with_clean_env {}"
      lic_exec_ruby! code.dump
      expect(last_command.stdboth).not_to include(
        "[DEPRECATED FOR 2.0] `Lic.with_clean_env` has been deprecated in favor of `Lic.with_unlicd_env`. " \
        "If you instead want the environment before lic was originally loaded, use `Lic.with_original_env`"
      )
    end
  end

  describe "Lic.with_unlicd_env" do
    it "should set ENV to unlicd_env in the block" do
      expected = Lic.unlicd_env
      actual = Lic.with_unlicd_env { ENV.to_hash }
      expect(actual).to eq(expected)
    end

    it "should restore the environment after execution" do
      Lic.with_unlicd_env do
        ENV["FOO"] = "hello"
      end

      expect(ENV).not_to have_key("FOO")
    end
  end

  describe "Lic.clean_system", :ruby => ">= 1.9", :lic => "< 2" do
    it "runs system inside with_clean_env" do
      Lic.clean_system(%(echo 'if [ "$LIC_PATH" = "" ]; then exit 42; else exit 1; fi' | /bin/sh))
      expect($?.exitstatus).to eq(42)
    end
  end

  describe "Lic.clean_exec", :ruby => ">= 1.9", :lic => "< 2" do
    it "runs exec inside with_clean_env" do
      pid = Kernel.fork do
        Lic.clean_exec(%(echo 'if [ "$LIC_PATH" = "" ]; then exit 42; else exit 1; fi' | /bin/sh))
      end
      Process.wait(pid)
      expect($?.exitstatus).to eq(42)
    end
  end
end
