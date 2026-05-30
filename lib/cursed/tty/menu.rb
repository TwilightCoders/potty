# frozen_string_literal: true

require 'io/console'

module Cursed
  module TTY
    # Declarative menu system with automatic navigation
    # Build entire menu tree upfront, then call run() once
    #
    # Requires a logger object that responds to puts, puts_success,
    # puts_error, puts_info, puts_warn, puts_dim
    class Menu
      attr_reader :title, :width
      attr_accessor :parent, :logger

      def initialize(title, width: 70, parent: nil, logger: nil, &block)
        @title = title
        @width = width
        @parent = parent
        @logger = logger || DefaultLogger.new
        @options = []
        @status_block = nil
        @current_menu = self
        @running = false
        @quit_menu = nil
        @flash_message = nil
        @flash_type = nil

        yield(self) if block_given?
      end

      def run
        @running = true
        build_quit_menu
        while @running
          @current_menu.display
          choice = get_input
          @current_menu.handle_choice(choice, self)
        end
      end

      def display
        clear_screen
        show_header
        @status_block&.call
        show_flash
        show_menu
        show_prompt
      end

      def handle_choice(choice, root)
        if choice == 'b'
          if @parent
            root.navigate_to(@parent)
          else
            root.navigate_to(root.instance_variable_get(:@quit_menu))
          end
          return
        end

        option = @options.find { |opt| opt[:key] == choice }

        if option
          case option[:type]
          when :action
            option[:action].call
          when :submenu
            root.navigate_to(option[:submenu])
          when :back
            if @parent
              root.navigate_to(@parent)
            else
              root.navigate_to(root.instance_variable_get(:@quit_menu))
            end
          when :quit
            root.navigate_to(root.instance_variable_get(:@quit_menu))
          end
        else
          show_error("Invalid option.")
          wait_for_enter
        end
      end

      def navigate_to(menu)
        @current_menu = menu
      end

      def quit
        @running = false
      end

      def build_quit_menu
        root_menu = self
        @quit_menu = Menu.new("Exit Confirmation", width: @width, parent: self, logger: @logger) do |m|
          m.status do
            @logger.puts("")
            @logger.puts_warn("Exit the program?")
            @logger.puts("")
          end

          m.option('y', 'Yes, exit', color: :green) do
            root_menu.quit
          end

          m.option('n', 'No, go back', color: :yellow) do
            root_menu.navigate_to(root_menu)
          end

          m.back_option
        end
      end

      # Flash message methods
      def flash_success(message)
        @flash_message = message
        @flash_type = :success
      end

      def flash_error(message)
        @flash_message = message
        @flash_type = :error
      end

      def flash_info(message)
        @flash_message = message
        @flash_type = :info
      end

      def flash_warn(message)
        @flash_message = message
        @flash_type = :warn
      end

      # DSL Methods
      def status(&block)
        @status_block = block
      end

      def option(key, description, color: :green, action: nil, menu: nil, &block)
        if menu
          menu.parent = self if menu.respond_to?(:parent=)
          @options << {
            key: key.to_s,
            description: description,
            color: color,
            type: :submenu,
            submenu: menu
          }
        else
          action_obj = action || (block ? proc_to_action(block) : nil)
          @options << {
            key: key.to_s,
            description: description,
            color: color,
            type: :action,
            action: action_obj
          }
        end
      end

      def submenu(title, &block)
        Menu.new(title, width: @width, parent: self, logger: @logger, &block)
      end

      def back_option(key: 'b', description: 'Back to previous menu', color: :blue)
        @options << {
          key: key.to_s,
          description: description,
          color: color,
          type: :back
        }
      end

      def quit_option(key: 'q', description: 'Exit', color: :yellow)
        @options << {
          key: key.to_s,
          description: description,
          color: color,
          type: :quit
        }
      end

      private

      def proc_to_action(block)
        Class.new(Action) do
          define_method(:initialize) do |blk|
            @block = blk
          end

          define_method(:call) do
            @block.call
          end
        end.new(block)
      end

      def clear_screen
        print "\033[2J\033[3J\033[H"
      end

      def show_header
        @logger.puts(colorize(("\u2550" * @width), :bold))
        @logger.puts(colorize("  #{@title}", :bold))
        @logger.puts(colorize(("\u2550" * @width), :bold))
        @logger.puts("")
      end

      def show_flash
        return unless @flash_message

        case @flash_type
        when :success then @logger.puts_success(@flash_message)
        when :error   then @logger.puts_error(@flash_message)
        when :info    then @logger.puts_info(@flash_message)
        when :warn    then @logger.puts_warn(@flash_message)
        end

        @logger.puts("")
        @flash_message = nil
        @flash_type = nil
      end

      def show_menu
        @logger.puts(colorize(("\u2500" * @width), :bold))
        @logger.puts(colorize("  MENU", :bold))
        @logger.puts(colorize(("\u2500" * @width), :bold))
        @logger.puts("")

        @options.each do |opt|
          @logger.puts("  #{colorize("[#{opt[:key]}]", opt[:color])} #{opt[:description]}")
        end

        @logger.puts("")
      end

      def show_prompt
        print "  #{colorize('Choose an option:', :bold)} "
      end

      def get_input
        require 'io/console'

        loop do
          begin
            char = $stdin.getch
          rescue Errno::ENOTTY, Errno::ENOTSUP => e
            show_error(e.message)
            print "\n  Enter choice: "
            line = $stdin.gets
            return line ? line.strip.downcase[0] : 'q'
          end

          if char == "\e"
            if IO.select([$stdin], nil, nil, 0.001)
              $stdin.getch
              $stdin.getch
              next
            else
              return 'b'
            end
          end

          raise Interrupt if char == "\u0003"

          return char.downcase if char.match?(/[[:print:]]/)
        end
      end

      def show_error(message)
        @logger.puts("")
        @logger.puts_error("  #{message}")
        @logger.puts("")
      end

      def wait_for_enter(message: "Press Enter to continue...")
        @logger.puts("")
        @logger.puts_dim(message)
        $stdin.gets
      end

      def colorize(text, color)
        if text.respond_to?(:colorize)
          text.colorize(color)
        else
          text.to_s
        end
      end

      # Default logger that just outputs to stdout
      class DefaultLogger
        def puts(msg = "")
          Kernel.puts(msg)
        end

        def puts_success(msg) = puts(msg)
        def puts_error(msg) = puts(msg)
        def puts_info(msg) = puts(msg)
        def puts_warn(msg) = puts(msg)
        def puts_dim(msg) = puts(msg)
      end
    end
  end
end
