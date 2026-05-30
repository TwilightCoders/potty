# frozen_string_literal: true

require 'curses'
require_relative 'base'

module Cursed
  module Widgets
    # Single-line editable text field. Shows a block cursor when focused,
    # a dim placeholder when empty and unfocused, and scrolls horizontally
    # when the text outgrows the field.
    #
    # ASCII input only for now (matches the rest of the framework); UTF-8
    # entry would need multibyte getch handling.
    class TextInput < Base
      # Resolved with fallbacks so we work across curses versions/builds.
      KEY_HOME = defined?(::Curses::Key::HOME) ? ::Curses::Key::HOME : 262
      KEY_END  = defined?(::Curses::Key::END)  ? ::Curses::Key::END  : 360
      KEY_DC   = defined?(::Curses::Key::DC)   ? ::Curses::Key::DC   : 330

      attr_reader :text
      attr_accessor :placeholder, :max_length, :on_change

      def initialize(app, text: '', placeholder: '', max_length: nil, on_change: nil)
        super(app)
        @text = text.dup
        @placeholder = placeholder
        @max_length = max_length
        @on_change = on_change
        @cursor = @text.length
        @scroll = 0
      end

      def can_focus?
        true
      end

      def text=(value)
        @text = value.to_s.dup
        @cursor = [@cursor, @text.length].min
        notify_change
      end

      def preferred_height(_width)
        1
      end

      def handle_key(ch)
        case ch
        when ::Curses::Key::LEFT
          @cursor = [@cursor - 1, 0].max
        when ::Curses::Key::RIGHT
          @cursor = [@cursor + 1, @text.length].min
        when KEY_HOME, 1 # Home / Ctrl+A
          @cursor = 0
        when KEY_END, 5  # End / Ctrl+E
          @cursor = @text.length
        when 127, 8, ::Curses::Key::BACKSPACE
          backspace
        when KEY_DC, 4   # Delete / Ctrl+D
          delete_forward
        when 32..126
          insert(ch.chr)
        else
          return false
        end
        true
      end

      def render(window)
        return unless @visible && @rect

        width = @rect.width
        adjust_scroll(width)

        if @text.empty? && !@focused
          window.setpos(@rect.y, @rect.x)
          window.attron(theme[:dim]) do
            window.addstr(@placeholder.to_s[0, width].to_s.ljust(width))
          end
          return
        end

        visible = (@text[@scroll, width] || '').ljust(width)
        window.setpos(@rect.y, @rect.x)
        window.attron(theme[:normal]) { window.addstr(visible) }

        return unless @focused

        # Block cursor: reverse-video the cell under the caret.
        col = @cursor - @scroll
        return if col.negative? || col >= width

        char_under = @text[@cursor] || ' '
        window.setpos(@rect.y, @rect.x + col)
        window.attron(theme[:normal] | ::Curses::A_REVERSE) do
          window.addstr(char_under)
        end
      end

      private

      def insert(str)
        return if @max_length && @text.length >= @max_length

        @text.insert(@cursor, str)
        @cursor += str.length
        notify_change
      end

      def backspace
        return if @cursor.zero?

        @text.slice!(@cursor - 1)
        @cursor -= 1
        notify_change
      end

      def delete_forward
        return if @cursor >= @text.length

        @text.slice!(@cursor)
        notify_change
      end

      def adjust_scroll(width)
        return if width <= 0

        @scroll = @cursor - width + 1 if @cursor - @scroll >= width
        @scroll = @cursor if @cursor < @scroll
        @scroll = [@scroll, 0].max
      end

      def notify_change
        # Hand the callback a snapshot, not the live internal buffer, so a
        # consumer that stores the value doesn't see it mutate underfoot.
        @on_change&.call(@text.dup)
      end
    end
  end
end
