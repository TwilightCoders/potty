# frozen_string_literal: true

require 'curses'
require_relative 'base'

module Cursed
  module Widgets
    # N mutually exclusive options, one row each. Up/down move the cursor;
    # Space/Enter selects the option under the cursor. Renders "(\u25CF) label"
    # for the chosen option and "(\u25CB) label" for the rest.
    #
    # Note the two distinct positions: the *cursor* (highlight, moved by
    # arrows) and the *selection* (the committed value). They diverge while
    # the user is navigating and reconverge on select.
    class RadioGroup < Base
      attr_accessor :on_change

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

      def options
        @options
      end

      def options=(opts)
        @options = normalize(opts)
        @cursor = @cursor.clamp(0, [@options.size - 1, 0].max)
      end

      def selected
        @selected
      end

      def selected=(value)
        idx = index_of(value)
        return unless idx

        @selected = value
        @cursor = idx
        @on_change&.call(@selected)
      end

      def preferred_height(_width)
        @options.size
      end

      def handle_key(ch)
        case ch
        when ::Curses::Key::UP
          move(-1)
        when ::Curses::Key::DOWN
          move(1)
        when 32, 10, 13 # Space / Enter
          choose(@cursor)
        else
          return false
        end
        true
      end

      def render(window)
        return unless @visible && @rect

        @options.each_with_index do |opt, i|
          break if i >= @rect.height

          marker = opt[:value] == @selected ? "(\u25CF)" : "(\u25CB)"
          on_cursor = @focused && i == @cursor
          attr = on_cursor ? theme.attr(:selected, bold: true) : theme[:normal]
          text = "#{marker} #{opt[:label]}"[0, @rect.width]

          window.setpos(@rect.y + i, @rect.x)
          window.attron(attr) { window.addstr(text) }
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

      def choose(idx)
        opt = @options[idx]
        return unless opt
        return if opt[:value] == @selected

        @selected = opt[:value]
        @on_change&.call(@selected)
      end

      def index_of(value)
        @options.index { |o| o[:value] == value }
      end
    end
  end
end
