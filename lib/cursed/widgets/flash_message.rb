# frozen_string_literal: true

require_relative 'base'

module Cursed
  module Widgets
    # Temporary notification message
    class FlashMessage < Base
      attr_reader :message, :type

      def initialize(app)
        super
        @message = nil
        @type = :info
        @timeout = nil
      end

      def show(message, type: :info, timeout: 5)
        @message = message
        @type = type
        @timeout = Time.now + timeout if timeout
      end

      def clear
        @message = nil
        @timeout = nil
      end

      def preferred_height(width)
        1
      end

      def render(window)
        return unless @rect

        # Auto-clear if timed out
        if @message && @timeout && Time.now > @timeout
          clear
        end

        # Clear the line first
        window.setpos(@rect.y, @rect.x)
        window.addstr(" " * @rect.width)

        # Show message if present
        if @message
          attr = case @type
                 when :success then theme[:success]
                 when :error then theme[:error]
                 when :warning then theme[:warning]
                 else theme[:info]
                 end

          window.setpos(@rect.y, @rect.x)
          window.attron(attr) do
            prefix = case @type
                     when :success then "\u2713 "
                     when :error then "\u2717 "
                     when :warning then "\u26A0 "
                     else "\u2139 "
                     end
            text = "#{prefix}#{@message}"[0, @rect.width]
            window.addstr(text)
          end
        end
      end
    end
  end
end
