# frozen_string_literal: true

require 'curses'
require_relative '../keys'

module Potty
  module Widgets
    # Base list item
    class ListItem
      attr_reader :text, :value
      attr_accessor :color

      def initialize(text, value: nil, color: nil)
        @text = text
        @value = value
        @color = color
      end

      def display_text
        @text
      end

      # Override this to render with multiple colors
      # Should call window.addstr() for each segment with different colors
      # Return true if custom rendering was done, false to use default
      def render_custom(window, theme, max_width)
        false
      end

      def disabled?
        false
      end

      def activate
        # Override in subclasses
      end

      def handle_key(ch)
        false
      end
    end

    # Action item - executes callback when activated
    class ActionItem < ListItem
      def initialize(text, value: nil, color: nil, &action)
        super(text, value: value, color: color)
        @action = action
      end

      def activate
        @action&.call(self)
      end
    end

    # Disabled/greyed item
    class DisabledItem < ListItem
      def disabled?
        true
      end
    end

    # Text input item - allows inline text editing
    class InputItem < ListItem
      attr_accessor :input_value

      def initialize(label, default: "", &on_submit)
        super(label)
        @input_value = default
        @on_submit = on_submit
        @cursor_pos = @input_value.length
      end

      def display_text
        cursor = "_"
        "#{@text}: #{@input_value}#{cursor}"
      end

      def handle_key(ch)
        case ch
        when *Keys::ENTERS
          @on_submit&.call(@input_value)
          true
        when *Keys::BACKSPACES
          if @cursor_pos > 0
            @input_value[@cursor_pos - 1] = ''
            @cursor_pos -= 1
          end
          true
        when Keys::LEFT
          @cursor_pos = [@cursor_pos - 1, 0].max
          true
        when Keys::RIGHT
          @cursor_pos = [@cursor_pos + 1, @input_value.length].min
          true
        when Keys::SPACE..(Keys::DEL_ASCII - 1)  # Printable ASCII
          @input_value.insert(@cursor_pos, ch.chr)
          @cursor_pos += 1
          true
        else
          false
        end
      end
    end

    # Separator - visual divider, not selectable
    class SeparatorItem < ListItem
      def initialize(text = "")
        super(text)
      end

      def disabled?
        true
      end

      def display_text
        @text.empty? ? ("\u2500" * 40) : @text
      end
    end
  end
end
