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
      attr_accessor :placeholder, :on_change, :cursor_shape

      def initialize(app, text: '', placeholder: '', max_length: nil, on_change: nil, cursor_shape: :bar)
        super(app)
        @editor = LineEditor.new(text, max_length: max_length)
        @placeholder = placeholder
        @on_change = on_change
        @cursor_shape = cursor_shape
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
        1 + chrome_height
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

        draw_focus_chrome(window)
        rect = content_rect
        width = rect.width
        adjust_scroll(width)

        if text.empty? && !@focused
          window.setpos(rect.y, rect.x)
          window.attron(theme.style(:dim)) do
            window.addstr(@placeholder.to_s[0, width].to_s.ljust(width))
          end
          return
        end

        visible = (text[@scroll, width] || '').ljust(width)
        window.setpos(rect.y, rect.x)
        window.attron(field_style) { window.addstr(visible) }

        return unless @focused

        # Place the real hardware text cursor at the caret. The surface shows
        # it on present (and hides it when no widget asks), so the focused
        # field gets a genuine blinking caret in the requested shape rather
        # than a faked reverse-video cell. Duck-typed windows that don't
        # support it (e.g. test fakes) simply skip the caret.
        col = @editor.cursor - @scroll
        return if col.negative? || col >= width
        return unless window.respond_to?(:place_cursor)

        window.place_cursor(rect.y, rect.x + col, shape: @cursor_shape)
      end

      private

      # The style the field text renders in. When the focus_style asks for a
      # fill and we're focused, the whole (ljust-padded) field paints in the
      # fill colour so an empty focused field is still visibly "lit"; otherwise
      # plain normal text.
      def field_style
        fs = focus_style
        return theme.style(fs.fill_color) if @focused && fs.fill

        theme.style(:normal)
      end

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
