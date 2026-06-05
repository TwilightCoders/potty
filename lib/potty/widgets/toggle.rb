# frozen_string_literal: true

require_relative 'base'
require_relative '../keys'

module Potty
  module Widgets
    # Boolean on/off control. Space (or Enter) flips it when focused.
    # Renders "[\u25CF] label" when on, "[\u25CB] label" when off.
    # Emits :change(value) when toggled.
    class Toggle < Base
      emits :change

      attr_reader :value
      attr_accessor :label

      def initialize(app, label: '', value: false, on_change: nil)
        super(app)
        @label = label
        @value = value
        @on_change = on_change
      end

      def can_focus?
        true
      end

      def value=(val)
        val = val ? true : false
        return if val == @value

        @value = val
        fire_change(@value)
      end

      # Set the value WITHOUT emitting :change — for a caller deriving this
      # toggle's state from another control (e.g. a master toggle mirroring a
      # checkbox group), where echoing the change back through on_change would
      # bounce between the two sync handlers. Not toggle-specific reasoning:
      # any derived/synchronized widget state wants a non-emitting write.
      # Use `value=` when the change should behave like user input.
      def replace_value(val)
        @value = val ? true : false
      end

      def toggle
        self.value = !@value
      end

      def preferred_height(_width)
        1 + chrome_height
      end

      def handle_key(ch)
        case ch
        when Keys::SPACE, *Keys::ENTERS
          toggle
          true
        else
          false
        end
      end

      def draw(window)
        rect = content_rect
        knob = @value ? "[\u25CF]" : "[\u25CB]"
        text = "#{knob} #{@label}"[0, rect.width]
        attr = theme.selection_style(@focused)

        window.setpos(rect.y, rect.x)
        window.attron(attr) { window.addstr(text) }
      end
    end
  end
end
