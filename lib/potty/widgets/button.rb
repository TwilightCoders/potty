# frozen_string_literal: true

require_relative 'base'
require_relative '../keys'

module Potty
  module Widgets
    # Focusable push button. Space/Enter fires :press. Pass on_press: for a
    # one-liner, or wire it with button.on(:press) { ... }. Either way the
    # callback receives the button as its argument (the :press payload), so
    # write `->(btn) { … }` (or `->(_btn) { … }` if you don't need it) — a
    # zero-arg `-> { … }` lambda will raise on the extra arg.
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
        1 + chrome_height
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

        draw_focus_chrome(window)
        rect = content_rect
        text = "[ #{@label} ]"[0, rect.width]
        attr = @focused ? theme.style(:selected, bold: true) : theme.style(@color)
        window.setpos(rect.y, rect.x)
        window.attron(attr) { window.addstr(text) }
      end
    end
  end
end
