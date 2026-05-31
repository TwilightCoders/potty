# frozen_string_literal: true

require_relative 'base'

module Potty
  module Widgets
    # Static, non-focusable text — form field labels, headings, captions.
    # Single line, truncated to the rect width. Color is a theme name;
    # `bold:` ORs in A_BOLD via the theme.
    class Label < Base
      attr_accessor :text, :color, :bold

      def initialize(app, text: '', color: :normal, bold: false)
        super(app)
        @text = text
        @color = color
        @bold = bold
      end

      def can_focus?
        false
      end

      def preferred_height(_width)
        1
      end

      def draw(window)
        attr = theme.style(@color, bold: @bold)
        window.setpos(@rect.y, @rect.x)
        window.attron(attr) { window.addstr(@text.to_s[0, @rect.width] || '') }
      end
    end
  end
end
