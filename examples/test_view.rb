# frozen_string_literal: true

require_relative '../lib/potty'

module Potty
  module Examples
    # Simple test view to verify curses setup
    class TestView < Potty::View
      def build_layout
        @flash = Widgets::FlashMessage.new(app)

        @list = Widgets::List.new(app)
        @list.items = build_test_items
        @list.on_activate = proc { |item| handle_activation(item) }

        @status = Widgets::StatusBar.new(app)
        @status.left_text = "\u2191\u2193: Navigate"
        @status.center_text = "CURSES TEST"
        @status.right_text = "ESC: Quit"

        @widgets = [@flash, @list, @status]
        @list.focus
      end

      def build_test_items
        items = []

        items << Widgets::SeparatorItem.new("\u2501\u2501 TEST ITEMS \u2501\u2501")

        items << Widgets::ActionItem.new("Show success message") do
          flash_success("This is a success message!")
        end

        items << Widgets::ActionItem.new("Show error message") do
          flash_error("This is an error message!")
        end

        items << Widgets::ActionItem.new("Show info message") do
          flash_info("This is an info message!")
        end

        items << Widgets::SeparatorItem.new

        items << Widgets::DisabledItem.new("This item is disabled")

        items << Widgets::SeparatorItem.new("\u2501\u2501 INPUT TEST \u2501\u2501")

        items << Widgets::InputItem.new("Type something", default: "") do |value|
          flash_success("You typed: #{value}")
        end

        items << Widgets::SeparatorItem.new

        items << Widgets::ActionItem.new("Quit application") do
          app.quit
        end

        items
      end

      def handle_activation(item)
        # Item handles its own activation
      end

      def handle_escape
        app.quit
        true
      end
    end
  end
end

# Run the test if executed directly
if __FILE__ == $0
  begin
    app = Potty::Application.new
    root_view = Potty::Examples::TestView.new(app)
    app.run(root_view)
  rescue Interrupt
    puts "\nInterrupted. Exiting..."
    exit 130
  rescue StandardError => e
    puts "Error: #{e.message}"
    puts e.backtrace if ENV['DEBUG']
    exit 1
  end
end
