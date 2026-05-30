# frozen_string_literal: true

require 'io/console'

module Cursed
  module TTY
    # Interactive list with context-aware menu options
    # Menu options change based on which item is selected
    # Single-key activation (no Enter needed)
    #
    # Requires a logger object that responds to puts, puts_dim
    class ListMenu
      attr_reader :title, :width
      attr_accessor :logger

      def initialize(title, width: 70, logger: nil, &block)
        @title = title
        @width = width
        @logger = logger || Menu::DefaultLogger.new
        @items = []
        @selected_index = 0
        @global_options = []
        @context_options_block = nil
        @status_block = nil
        @format_item_block = nil
        @done = false

        yield(self) if block_given?
      end

      def items(array)
        @items = array
      end

      def format_item(&block)
        @format_item_block = block
      end

      def status(&block)
        @status_block = block
      end

      def context_options(&block)
        @context_options_block = block
      end

      def global_option(key, description, color: :blue, &action)
        @global_options << {
          key: key.to_s,
          description: description,
          color: color,
          action: action
        }
      end

      def back_option(key: 'b', description: 'Back', color: :blue)
        @global_options << {
          key: key.to_s,
          description: description,
          color: color,
          action: -> { @done = true }
        }
      end

      def run
        @selected_index = 0
        @done = false

        loop do
          @selected_index = 0 if !@items.empty? && @selected_index >= @items.length
          display
          handle_input
          return if @done
        end
      end

      private

      def display
        clear_screen
        show_header
        @status_block&.call
        show_list
        show_menu_options
      end

      def show_header
        @logger.puts(colorize(("\u2550" * @width), :bold))
        @logger.puts(colorize("  #{@title}", :bold))
        @logger.puts(colorize(("\u2550" * @width), :bold))
        @logger.puts("")
      end

      def show_list
        @logger.puts(colorize("  Items:", :cyan))
        @logger.puts("")

        if @items.empty?
          @logger.puts(colorize("  No items", :light_black))
        else
          @items.each_with_index do |item, index|
            if index == @selected_index
              formatted = format_item_for_display(item, index)
              @logger.puts("  #{colorize("\u2192", :green)} #{formatted}")
            else
              formatted = format_item_for_display(item, index)
              @logger.puts("    #{formatted}")
            end
          end
        end

        @logger.puts("")
      end

      def format_item_for_display(item, index)
        if @format_item_block
          @format_item_block.call(item, index)
        else
          "[#{index}] #{item}"
        end
      end

      def show_menu_options
        @logger.puts(colorize(("\u2500" * @width), :bold))
        @logger.puts(colorize("  OPTIONS", :bold))
        @logger.puts(colorize(("\u2500" * @width), :bold))
        @logger.puts("")

        unless @items.empty?
          selected_item = @items[@selected_index]
          context_opts = @context_options_block ? @context_options_block.call(selected_item) : []

          unless context_opts.empty?
            @logger.puts(colorize("  For selected item:", :light_black))
            context_opts.each do |opt|
              @logger.puts("  #{colorize("[#{opt[:key]}]", opt[:color] || :cyan)} #{opt[:description]}")
            end
            @logger.puts("")
          end
        end

        unless @global_options.empty?
          @logger.puts(colorize("  General:", :light_black))
          @global_options.each do |opt|
            @logger.puts("  #{colorize("[#{opt[:key]}]", opt[:color])} #{opt[:description]}")
          end
          @logger.puts("")
        end

        help_text = @items.empty? ? "Press key to activate option" : "Use \u2191\u2193 arrows to navigate, press key to activate"
        @logger.puts_dim(help_text)
      end

      def handle_input
        char = $stdin.getch

        case char
        when "\e"
          if IO.select([$stdin], nil, nil, 0.001)
            bracket = $stdin.getch
            if bracket == '['
              direction = $stdin.getch
              unless @items.empty?
                case direction
                when 'A'
                  @selected_index = (@selected_index - 1) % @items.length
                when 'B'
                  @selected_index = (@selected_index + 1) % @items.length
                end
              end
            end
          else
            @done = true
          end
        when "\u0003"
          raise Interrupt
        else
          handle_option_key(char)
        end
      end

      def handle_option_key(char)
        unless @items.empty?
          selected_item = @items[@selected_index]
          context_opts = @context_options_block ? @context_options_block.call(selected_item) : []

          context_opt = context_opts.find { |opt| opt[:key] == char }
          if context_opt && context_opt[:action]
            context_opt[:action].call(selected_item)
            return
          end
        end

        global_opt = @global_options.find { |opt| opt[:key] == char }
        if global_opt && global_opt[:action]
          item = @items.empty? ? nil : @items[@selected_index]
          global_opt[:action].call(item)
        end
      end

      def clear_screen
        print "\033[2J\033[3J\033[H"
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
