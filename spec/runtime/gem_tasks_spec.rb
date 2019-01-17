# frozen_string_literal: true

RSpec.describe "require 'lic/gem_tasks'", :ruby_repo do
  before :each do
    licd_app("foo.gemspec").open("w") do |f|
      f.write <<-GEMSPEC
        Gem::Specification.new do |s|
          s.name = "foo"
        end
      GEMSPEC
    end
    licd_app("Rakefile").open("w") do |f|
      f.write <<-RAKEFILE
        $:.unshift("#{lic_path}")
        require "lic/gem_tasks"
      RAKEFILE
    end
  end

  it "includes the relevant tasks" do
    with_gem_path_as(Spec::Path.base_system_gems.to_s) do
      sys_exec "#{rake} -T"
    end

    expect(err).to eq("")
    expected_tasks = [
      "rake build",
      "rake clean",
      "rake clobber",
      "rake install",
      "rake release[remote]",
    ]
    tasks = out.lines.to_a.map {|s| s.split("#").first.strip }
    expect(tasks & expected_tasks).to eq(expected_tasks)
    expect(exitstatus).to eq(0) if exitstatus
  end

  it "adds 'pkg' to rake/clean's CLOBBER" do
    with_gem_path_as(Spec::Path.base_system_gems.to_s) do
      sys_exec! %(#{rake} -e 'load "Rakefile"; puts CLOBBER.inspect')
    end
    expect(last_command.stdout).to eq '["pkg"]'
  end
end
