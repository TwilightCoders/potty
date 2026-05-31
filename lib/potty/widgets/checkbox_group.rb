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

      emits :change

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
        fire_change(selected)
      end

      def selected?(value)
        @selected.include?(value)
      end

      def preferred_height(_width)
        @options.size + chrome_height
      end

      private

      # OptionList hooks.
      def commit_at(idx)
        opt = @options[idx]
        return unless opt

        value = opt[:value]
        selected?(value) ? @selected.delete(value) : (@selected << value)
        fire_change(selected)
      end

      def row_marker(opt)
        selected?(opt[:value]) ? "[\u2713]" : "[ ]"
      end
    end
  end
end
