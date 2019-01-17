# frozen_string_literal: true

module Lic
  module CLI::Common
    def self.output_post_install_messages(messages)
      return if Lic.settings["ignore_messages"]
      messages.to_a.each do |name, msg|
        print_post_install_message(name, msg) unless Lic.settings["ignore_messages.#{name}"]
      end
    end

    def self.print_post_install_message(name, msg)
      Lic.ui.confirm "Post-install message from #{name}:"
      Lic.ui.info msg
    end

    def self.output_without_groups_message
      return if Lic.settings[:without].empty?
      Lic.ui.confirm without_groups_message
    end

    def self.without_groups_message
      groups = Lic.settings[:without]
      group_list = [groups[0...-1].join(", "), groups[-1..-1]].
        reject {|s| s.to_s.empty? }.join(" and ")
      group_str = groups.size == 1 ? "group" : "groups"
      "Gems in the #{group_str} #{group_list} were not installed."
    end

    def self.select_spec(name, regex_match = nil)
      specs = []
      regexp = Regexp.new(name) if regex_match

      Lic.definition.specs.each do |spec|
        return spec if spec.name == name
        specs << spec if regexp && spec.name =~ regexp
      end

      case specs.count
      when 0
        raise GemNotFound, gem_not_found_message(name, Lic.definition.dependencies)
      when 1
        specs.first
      else
        ask_for_spec_from(specs)
      end
    rescue RegexpError
      raise GemNotFound, gem_not_found_message(name, Lic.definition.dependencies)
    end

    def self.ask_for_spec_from(specs)
      if !$stdout.tty? && ENV["LIC_SPEC_RUN"].nil?
        raise GemNotFound, gem_not_found_message(name, Lic.definition.dependencies)
      end

      specs.each_with_index do |spec, index|
        Lic.ui.info "#{index.succ} : #{spec.name}", true
      end
      Lic.ui.info "0 : - exit -", true

      num = Lic.ui.ask("> ").to_i
      num > 0 ? specs[num - 1] : nil
    end

    def self.gem_not_found_message(missing_gem_name, alternatives)
      require "lic/similarity_detector"
      message = "Could not find gem '#{missing_gem_name}'."
      alternate_names = alternatives.map {|a| a.respond_to?(:name) ? a.name : a }
      suggestions = SimilarityDetector.new(alternate_names).similar_word_list(missing_gem_name)
      message += "\nDid you mean #{suggestions}?" if suggestions
      message
    end

    def self.ensure_all_gems_in_lockfile!(names, locked_gems = Lic.locked_gems)
      locked_names = locked_gems.specs.map(&:name).uniq
      names.-(locked_names).each do |g|
        raise GemNotFound, gem_not_found_message(g, locked_names)
      end
    end

    def self.configure_gem_version_promoter(definition, options)
      patch_level = patch_level_options(options)
      raise InvalidOption, "Provide only one of the following options: #{patch_level.join(", ")}" unless patch_level.length <= 1
      definition.gem_version_promoter.tap do |gvp|
        gvp.level = patch_level.first || :major
        gvp.strict = options[:strict] || options["update-strict"] || options["filter-strict"]
      end
    end

    def self.patch_level_options(options)
      [:major, :minor, :patch].select {|v| options.keys.include?(v.to_s) }
    end

    def self.clean_after_install?
      clean = Lic.settings[:clean]
      return clean unless clean.nil?
      clean ||= Lic.feature_flag.auto_clean_without_path? && Lic.settings[:path].nil?
      clean &&= !Lic.use_system_gems?
      clean
    end
  end
end
