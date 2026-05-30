# frozen_string_literal: true

require 'io/console'

module Cursed
  module TTY
    # Interactive list selection with arrow keys or number input
    class ListSelector
      attr_accessor :logger

      def initialize(items, prompt: "Select an item", disabled_indices: [], logger: nil)
        @items = items
        @prompt = prompt
        @disabled_indices = disabled_indices
        @logger = logger || Menu::DefaultLogger.new
        @selected_index = find_next_enabled_index(0, direction: :down) || 0
        @done = false
      end

      def select
        display
        loop do
          handle_input
          return @result if @done
        end
      end

      private

      def display
        @items.each_with_index do |item, index|
          disabled = disabled?(index)

          if index == @selected_index
            text = format_item(item, index)
            @logger.puts("  #{colorize("\u2192", :green)} #{text}")
          elsif disabled
            text = format_item(item, index)
            @logger.puts("    #{colorize(text, :light_black)}")
          else
            @logger.puts("    #{format_item(item, index)}")
          end
        end

        @logger.puts("")
        @logger.puts_dim("Use \u2191\u2193 arrows to navigate, Enter to select, number to jump, ESC to cancel")
        print "  #{@prompt}: "
      end

      def redraw
        clear_display
        display
      end

      def format_item(item, index)
        if item.is_a?(Hash)
          text = item[:text] || item[:path] || item.to_s
          label = item[:label]
          label_part = label ? " (#{label})" : ""
          "[#{index + 1}] #{text}#{label_part}"
        else
          "[#{index + 1}] #{item}"
        end
      end

      def handle_input
        char = $stdin.getch

        case char
        when "\e"
          if IO.select([$stdin], nil, nil, 0.001)
            bracket = $stdin.getch
            if bracket == '['
              direction = $stdin.getch
              case direction
              when 'A'
                next_index = find_next_enabled_index(@selected_index - 1, direction: :up)
                @selected_index = next_index if next_index
                redraw
              when 'B'
                next_index = find_next_enabled_index(@selected_index + 1, direction: :down)
                @selected_index = next_index if next_index
                redraw
              end
            end
          else
            @result = nil
            @done = true
          end

        when "\r", "\n"
          unless disabled?(@selected_index)
            @result = @selected_index
            @done = true
          end

        when '0'..'9'
          number_str = char
          print char

          loop do
            next_char = $stdin.getch
            if next_char =~ /\d/
              number_str << next_char
              print next_char
            elsif next_char == "\r" || next_char == "\n"
              index = number_str.to_i - 1
              if index >= 0 && index < @items.length
                if disabled?(index)
                  Kernel.puts
                  @logger.puts_error("That source is already added")
                  sleep 1
                  redraw
                else
                  @result = index
                  @done = true
                end
              else
                Kernel.puts
                @logger.puts_error("Invalid selection: #{number_str}")
                sleep 1
                redraw
              end
              break
            elsif next_char == "\e"
              Kernel.puts
              redraw
              break
            else
              break
            end
          end

        when "\u0003"
          raise Interrupt
        end
      end

      def clear_display
        lines_to_clear = @items.length + 2
        lines_to_clear.times do
          print "\e[1A"
          print "\e[2K"
        end
        print "\r"
      end

      def disabled?(index)
        @disabled_indices.include?(index)
      end

      def find_next_enabled_index(start_index, direction: :down)
        return nil if @items.empty?

        @items.length.times do |offset|
          index = if direction == :down
                    (start_index + offset) % @items.length
                  else
                    (start_index - offset) % @items.length
                  end
          return index unless disabled?(index)
        end

        nil
      end

      def colorize(text, color)
        if text.respond_to?(:colorize)
          text.colorize(color)
        else
          text.to_s
        end
      end
    end
  end
end
