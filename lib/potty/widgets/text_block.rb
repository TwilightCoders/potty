# frozen_string_literal: true

require_relative 'base'

module Potty
  module Widgets
    # Multi-line static text — the block sibling of Label. Hand it a String
    # with newlines and it renders each line, reporting its height as the line
    # count so the layout reserves the right number of rows (no more rendering
    # a 20-row QR as 20 separate Labels).
    #
    # `wrap: false` (default) renders the text verbatim, one source line per
    # row, truncated to the rect width — right for preformatted art / tables /
    # fixed-width output. `wrap: true` word-wraps each line to the rect width
    # (collapsing runs of spaces; over-long words are hard-broken) — right for
    # prose, log tails, error messages.
    #
    # Not focusable; carries no chrome (like Label).
    class TextBlock < Base
      attr_reader :text
      attr_accessor :color, :wrap

      def initialize(app, text: '', color: :normal, wrap: false)
        super(app)
        @text = text.to_s
        @color = color
        @wrap = wrap
      end

      def text=(value)
        @text = value.to_s
      end

      def preferred_height(width)
        lines(width).size
      end

      def render(window)
        return unless @visible && @rect

        rows = lines(@rect.width)
        rows.each_with_index do |line, i|
          break if i >= @rect.height

          window.setpos(@rect.y + i, @rect.x)
          window.attron(theme.style(@color)) { window.addstr(line[0, @rect.width].to_s) }
        end
      end

      private

      # The display lines for a given width: split on newlines (keeping blank
      # lines, including a trailing one), then word-wrap each if wrap is on.
      def lines(width)
        raw = @text.split("\n", -1)
        return raw unless @wrap && width.to_i.positive?

        raw.flat_map { |line| wrap_line(line, width) }
      end

      def wrap_line(line, width)
        return [''] if line.empty?

        out = []
        current = +''
        line.split(' ').each do |word|
          # Hard-break a word longer than the full width, flushing first.
          while word.length > width
            out << current unless current.empty?
            current = +''
            out << word[0, width]
            word = word[width..] || ''
          end
          next if word.empty?

          if current.empty?
            current = word.dup
          elsif current.length + 1 + word.length <= width
            current << ' ' << word
          else
            out << current
            current = word.dup
          end
        end
        out << current unless current.empty?
        out.empty? ? [''] : out
      end
    end
  end
end
