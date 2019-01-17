# frozen_string_literal: true

module Lic
  class CLI::Viz
    attr_reader :options, :gem_name
    def initialize(options)
      @options = options
    end

    def run
      # make sure we get the right `graphviz`. There is also a `graphviz`
      # gem we're not built to support
      gem "ruby-graphviz"
      require "graphviz"

      options[:without] = options[:without].join(":").tr(" ", ":").split(":")
      output_file = File.expand_path(options[:file])

      graph = Graph.new(Lic.load, output_file, options[:version], options[:requirements], options[:format], options[:without])
      graph.viz
    rescue LoadError => e
      Lic.ui.error e.inspect
      Lic.ui.warn "Make sure you have the graphviz ruby gem. You can install it with:"
      Lic.ui.warn "`gem install ruby-graphviz`"
    rescue StandardError => e
      raise unless e.message =~ /GraphViz not installed or dot not in PATH/
      Lic.ui.error e.message
      Lic.ui.warn "Please install GraphViz. On a Mac with Homebrew, you can run `brew install graphviz`."
    end
  end
end
