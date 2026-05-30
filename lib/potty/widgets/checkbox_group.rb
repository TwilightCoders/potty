# frozen_string_literal: true

require 'curses'
require_relative 'base'
require_relative '../keys'

module Potty
  module Widgets
    # Multi-select list of options, one row each. Up/down move a cursor,
    # Space/Enter toggles the option under it. The RadioGroup sibling for
    # "choose any number". Emits :change(selected_values) on each toggle.
    class CheckboxGroup < Base
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

      def options
        @options
      end

      # A snapshot of the selected values (safe to store).
      def selected
        @selected.dup
      end

      def selected?(value)
        @selected.include?(value)
      end

      def preferred_height(_width)
        @options.size
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

        @options.each_with_index do |opt, i|
          break if i >= @rect.height

          mark = selected?(opt[:value]) ? "[\u2713]" : "[ ]"
          on_cursor = @focused && i == @cursor
          attr = on_cursor ? theme.attr(:selected, bold: true) : theme[:normal]
          window.setpos(@rect.y + i, @rect.x)
          window.attron(attr) { window.addstr("#{mark} #{opt[:label]}"[0, @rect.width]) }
        end
      end

      private

      def normalize(opts)
        (opts || []).map do |o|
          if o.is_a?(Hash)
            { value: o[:value], label: (o[:label] || o[:value]).to_s }
          else
            { value: o, label: o.to_s }
          end
        end
      end

      def move(delta)
        return if @options.empty?

        @cursor = (@cursor + delta) % @options.size
      end

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
