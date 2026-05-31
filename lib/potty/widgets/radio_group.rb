# frozen_string_literal: true

require 'curses'
require_relative 'base'
require_relative 'option_list'
require_relative '../keys'

module Potty
  module Widgets
    # N mutually exclusive options, one row each. Up/down move the cursor;
    # Space/Enter selects the option under the cursor. Renders "(\u25CF) label"
    # for the chosen option and "(\u25CB) label" for the rest.
    #
    # Note the two distinct positions: the *cursor* (highlight, moved by
    # arrows) and the *selection* (the committed value). They diverge while
    # the user is navigating and reconverge on select.
    class RadioGroup < Base
      include OptionList

      emits :change

      def initialize(app, options: [], selected: nil, on_change: nil)
        super(app)
        @options = normalize(options)
        @on_change = on_change
        @selected = selected.nil? ? @options.first&.fetch(:value) : selected
        @cursor = index_of(@selected) || 0
      end

      def can_focus?
        true
      end

      def options=(opts)
        @options = normalize(opts)
        @cursor = @cursor.clamp(0, [@options.size - 1, 0].max)
      end

      def selected
        @selected
      end

      # The value under the cursor (the highlighted row), which may differ
      # from the committed selection while navigating. Choosers commit this
      # on Enter.
      def cursor_value
        opt = @options[@cursor]
        opt && opt[:value]
      end

      def selected=(value)
        idx = index_of(value)
        return unless idx

        @selected = value
        @cursor = idx
        fire_change(@selected)
      end

      def preferred_height(_width)
        @options.size + chrome_height
      end

      def handle_key(ch)
        case ch
        when Keys::UP
          move(-1)
        when Keys::DOWN
          move(1)
        when Keys::SPACE, *Keys::ENTERS
          choose(@cursor)
        else
          return false
        end
        true
      end

      def render(window)
        return unless @visible && @rect

        draw_focus_chrome(window)
        rect = content_rect
        @options.each_with_index do |opt, i|
          break if i >= rect.height

          marker = opt[:value] == @selected ? "(\u25CF)" : "(\u25CB)"
          on_cursor = @focused && i == @cursor
          attr = on_cursor ? theme.style(:selected, bold: true) : theme.style(:normal)
          text = "#{marker} #{opt[:label]}"[0, rect.width]

          window.setpos(rect.y + i, rect.x)
          window.attron(attr) { window.addstr(text) }
        end
      end

      private

      def choose(idx)
        opt = @options[idx]
        return unless opt
        return if opt[:value] == @selected

        @selected = opt[:value]
        fire_change(@selected)
      end
    end
  end
end
