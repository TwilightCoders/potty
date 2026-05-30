# frozen_string_literal: true

require 'curses'
require_relative '../keys'
require_relative '../line_editor'

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

    # Text input item — inline text editing within a List. Shares the
    # LineEditor model with the TextInput widget.
    class InputItem < ListItem
      def initialize(label, default: "", &on_submit)
        super(label)
        @editor = LineEditor.new(default)
        @on_submit = on_submit
      end

      # Back-compat accessor for the entered text.
      def input_value
        @editor.text
      end

      def input_value=(value)
        @editor.text = value
      end

      def display_text
        "#{@text}: #{@editor.text}_"
      end

      def handle_key(ch)
        case ch
        when *Keys::ENTERS
          @on_submit&.call(@editor.text)
        when *Keys::BACKSPACES
          @editor.backspace
        when Keys::LEFT
          @editor.left
        when Keys::RIGHT
          @editor.right
        when Keys::SPACE..(Keys::DEL_ASCII - 1) # Printable ASCII
          @editor.insert(ch.chr)
        else
          return false
        end
        true
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
