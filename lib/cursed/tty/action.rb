# frozen_string_literal: true

require_relative 'list_selector'

module Cursed
  module TTY
    # Base class for menu actions
    # Subclass this to create application-specific actions
    class Action
      # Execute the action
      # Override this in subclasses
      def call
        raise NotImplementedError, "Subclasses must implement #call"
      end

      # Helper methods available to actions

      def clear_screen
        print "\033[2J\033[3J\033[H"
      end

      def show_header(title, width: 70)
        puts(colorize(("\u2550" * width), :bold))
        puts(colorize("  #{title}", :bold))
        puts(colorize(("\u2550" * width), :bold))
        puts("")
      end

      def show_separator(title = nil, width: 70)
        puts(colorize(("\u2500" * width), :bold))
        if title
          puts(colorize("  #{title}", :bold))
          puts(colorize(("\u2500" * width), :bold))
        end
        puts("")
      end

      def wait_for_enter(message: "Press Enter to continue...")
        puts("")
        puts(colorize(message, :light_black))
        $stdin.gets
      end

      def prompt_input(label, cancel_hint: "(Enter to cancel)")
        require 'io/console'

        print "  #{label} #{colorize(cancel_hint, :light_black)}: "

        input = String.new

        loop do
          char = $stdin.getch

          if char == "\e"
            if IO.select([$stdin], nil, nil, 0.001)
              $stdin.getch
              $stdin.getch
              next
            else
              Kernel.puts
              return nil
            end
          end

          if char == "\u007F" || char == "\b"
            unless input.empty?
              input.chop!
              print "\b \b"
            end
            next
          end

          if char == "\r" || char == "\n"
            Kernel.puts
            return nil if input.empty?
            return input.gsub(/^[\"']|[\"']$/, '')
          end

          if char == "\u0003"
            Kernel.puts
            raise Interrupt
          end

          if char.match?(/[[:print:]]/)
            input << char
            print char
          end
        end
      end

      def confirm?(prompt, match: 'y', color: :yellow)
        print "  #{colorize(prompt, color)} "
        response = $stdin.gets&.strip&.downcase
        response == match
      end

      def format_number(num)
        num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
      end

      def get_input
        $stdin.gets&.strip&.downcase
      end

      def select_from_list(items, prompt: "Select an item", disabled_indices: [])
        selector = ListSelector.new(items, prompt: prompt, disabled_indices: disabled_indices)
        selector.select
      end

      private

      def colorize(text, color)
        if text.respond_to?(:colorize)
          text.colorize(color)
        else
          text.to_s
        end
      end

      def puts(message)
        Kernel.puts(message)
      end
    end
  end
end
