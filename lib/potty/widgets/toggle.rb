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

      def render(window)
        return unless @visible && @rect

        draw_focus_chrome(window)
        rect = content_rect
        knob = @value ? "[\u25CF]" : "[\u25CB]"
        text = "#{knob} #{@label}"[0, rect.width]
        attr = @focused ? theme.style(:selected, bold: true) : theme.style(:normal)

        window.setpos(rect.y, rect.x)
        window.attron(attr) { window.addstr(text) }
      end
    end
  end
end
