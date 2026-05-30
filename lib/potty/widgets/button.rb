# frozen_string_literal: true

require_relative 'base'
require_relative '../keys'

module Potty
  module Widgets
    # Focusable push button. Space/Enter fires :press. Pass on_press: for a
    # one-liner, or wire it with button.on(:press) { ... }.
    class Button < Base
      attr_accessor :label, :color

      def initialize(app, label: '', color: :normal, on_press: nil)
        super(app)
        @label = label
        @color = color
        on(:press, &on_press) if on_press
      end

      def can_focus?
        true
      end

      def preferred_height(_width)
        1
      end

      def press
        emit(:press, self)
      end

      def handle_key(ch)
        case ch
        when Keys::SPACE, *Keys::ENTERS
          press
          true
        else
          false
        end
      end

      def render(window)
        return unless @visible && @rect

        text = "[ #{@label} ]"[0, @rect.width]
        attr = @focused ? theme.attr(:selected, bold: true) : theme[@color]
        window.setpos(@rect.y, @rect.x)
        window.attron(attr) { window.addstr(text) }
      end
    end
  end
end
