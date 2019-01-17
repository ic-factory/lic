require "lic/vendor/thor/lib/thor/line_editor/basic"
require "lic/vendor/thor/lib/thor/line_editor/readline"

class Lic::Thor
  module LineEditor
    def self.readline(prompt, options = {})
      best_available.new(prompt, options).readline
    end

    def self.best_available
      [
        Lic::Thor::LineEditor::Readline,
        Lic::Thor::LineEditor::Basic
      ].detect(&:available?)
    end
  end
end
