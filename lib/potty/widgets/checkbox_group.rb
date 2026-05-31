# frozen_string_literal: true

require 'curses'
require_relative 'base'
require_relative 'option_list'
require_relative '../keys'

module Potty
  module Widgets
    # Multi-select list of options, one row each. Up/down move a cursor,
    # Space/Enter toggles the option under it. The RadioGroup sibling for
    # "choose any number". Emits :change(selected_values) on each toggle.
    class CheckboxGroup < Base
      include OptionList

      attr_accessor :on_change

      def initialize(app, options: [], selected: [], on_change: nil)
        super(app)
        @options = normalize(options)
        @selected = Array(selected).dup
        @cursor = 0
        @on_change = on_change
      end

      def can_focus?
        true
      end

      # A snapshot of the selected values (safe to store).
      def selected
        @selected.dup
      end

      # Replace the whole selection set programmatically — the hook for a
      # "master" / "select all" row driving its individual rows from outside,
      # without reaching into @selected. Pass the values to select (`[]` to
      # clear); unknown values and order/duplicates are ignored. Fires
      # :change (and on_change) like an interactive toggle, but only when the
      # set actually changes, so a master<->individuals wiring can't loop.
      def selected=(values)
        valid = @options.map { |o| o[:value] }
        next_sel = Array(values).uniq.select { |v| valid.include?(v) }
        return if (next_sel - @selected).empty? && (@selected - next_sel).empty?

        @selected = next_sel
        @on_change&.call(selected)
        emit(:change, selected)
      end

      def selected?(value)
        @selected.include?(value)
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
          toggle(@cursor)
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

          mark = selected?(opt[:value]) ? "[\u2713]" : "[ ]"
          on_cursor = @focused && i == @cursor
          attr = on_cursor ? theme.style(:selected, bold: true) : theme.style(:normal)
          window.setpos(rect.y + i, rect.x)
          window.attron(attr) { window.addstr("#{mark} #{opt[:label]}"[0, rect.width]) }
        end
      end

      private

      def toggle(idx)
        opt = @options[idx]
        return unless opt

        value = opt[:value]
        selected?(value) ? @selected.delete(value) : (@selected << value)
        @on_change&.call(selected)
        emit(:change, selected)
      end
    end
  end
end
