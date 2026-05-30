# frozen_string_literal: true

require_relative 'base'

module Potty
  module Widgets
    # Status bar at bottom of screen
    class StatusBar < Base
      attr_accessor :left_text, :center_text, :right_text

      def initialize(app)
        super
        @left_text = ""
        @center_text = ""
        @right_text = ""
      end

      def preferred_height(width)
        1
      end

      def render(window)
        return unless @rect

        window.setpos(@rect.y, @rect.x)
        window.attron(theme[:status]) do
          # Clear line with background color
          window.addstr(" " * @rect.width)

          # Left-aligned
          if @left_text && !@left_text.empty?
            window.setpos(@rect.y, @rect.x)
            max_left = @rect.width / 3
            window.addstr(@left_text[0, max_left])
          end

          # Center-aligned
          if @center_text && !@center_text.empty?
            center_x = @rect.x + (@rect.width - @center_text.length) / 2
            center_x = [center_x, @rect.x].max
            window.setpos(@rect.y, center_x)
            window.addstr(@center_text[0, @rect.width])
          end

          # Right-aligned
          if @right_text && !@right_text.empty?
            right_x = @rect.x + @rect.width - @right_text.length
            right_x = [right_x, @rect.x].max
            window.setpos(@rect.y, right_x)
            window.addstr(@right_text)
          end
        end
      end
    end
  end
end
