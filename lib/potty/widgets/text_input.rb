# frozen_string_literal: true

require_relative 'base'
require_relative '../keys'
require_relative '../line_editor'

module Potty
  module Widgets
    # Single-line editable text field. Shows a block cursor when focused,
    # a dim placeholder when empty and unfocused, and scrolls horizontally
    # when the text outgrows the field. The editing model is a LineEditor
    # (shared with the list InputItem); this widget owns rendering + scroll.
    #
    # Emits :change(text) on every edit. ASCII input only for now (matches
    # the rest of the framework); UTF-8 entry would need multibyte getch.
    class TextInput < Base
      attr_accessor :placeholder, :on_change

      def initialize(app, text: '', placeholder: '', max_length: nil, on_change: nil)
        super(app)
        @editor = LineEditor.new(text, max_length: max_length)
        @placeholder = placeholder
        @on_change = on_change
        @scroll = 0
      end

      def can_focus?
        true
      end

      def text
        @editor.text
      end

      def text=(value)
        @editor.text = value
        notify_change
      end

      def max_length
        @editor.max_length
      end

      def max_length=(value)
        @editor.max_length = value
      end

      def preferred_height(_width)
        1
      end

      def handle_key(ch)
        case ch
        when Keys::LEFT then @editor.left
        when Keys::RIGHT then @editor.right
        when Keys::HOME, Keys::CTRL_A then @editor.home
        when Keys::END_, Keys::CTRL_E then @editor.to_end
        when Keys::DEL_ASCII, Keys::CTRL_H, Keys::BACKSPACE then changed(@editor.backspace)
        when Keys::DELETE, Keys::CTRL_D then changed(@editor.delete_forward)
        when Keys::SPACE..(Keys::DEL_ASCII - 1) then changed(@editor.insert(ch.chr))
        else
          return false
        end
        true
      end

      def render(window)
        return unless @visible && @rect

        width = @rect.width
        adjust_scroll(width)

        if text.empty? && !@focused
          window.setpos(@rect.y, @rect.x)
          window.attron(theme.style(:dim)) do
            window.addstr(@placeholder.to_s[0, width].to_s.ljust(width))
          end
          return
        end

        visible = (text[@scroll, width] || '').ljust(width)
        window.setpos(@rect.y, @rect.x)
        window.attron(theme.style(:normal)) { window.addstr(visible) }

        return unless @focused

        # Block cursor: reverse-video the cell under the caret.
        col = @editor.cursor - @scroll
        return if col.negative? || col >= width

        char_under = text[@editor.cursor] || ' '
        window.setpos(@rect.y, @rect.x + col)
        window.attron(theme.style(:normal, reverse: true)) do
          window.addstr(char_under)
        end
      end

      private

      def changed(did_change)
        notify_change if did_change
      end

      def adjust_scroll(width)
        return if width <= 0

        cursor = @editor.cursor
        @scroll = cursor - width + 1 if cursor - @scroll >= width
        @scroll = cursor if cursor < @scroll
        @scroll = [@scroll, 0].max
      end

      def notify_change
        # Hand listeners a snapshot, not the live internal buffer, so a
        # consumer that stores the value doesn't see it mutate underfoot.
        snapshot = text.dup
        @on_change&.call(snapshot)
        emit(:change, snapshot)
      end
    end
  end
end
