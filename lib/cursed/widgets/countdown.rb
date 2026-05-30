# frozen_string_literal: true

require_relative 'base'

module Cursed
  module Widgets
    # Passive display that counts down from N seconds and fires on_expire
    # once when it reaches zero. Time-driven: it advances off the `now`
    # passed to tick(now), so drive it via the Application tick loop
    # (set Application#tick_interval).
    #
    # The clock starts on the first tick (not at construction), so a
    # Countdown built well before the loop spins up still gets its full N.
    class Countdown < Base
      attr_accessor :on_expire

      def initialize(app, seconds:, on_expire: nil, format: nil)
        super(app)
        @seconds = seconds.to_f
        @on_expire = on_expire
        @format = format || ->(remaining) { "Auto-launching in #{remaining}s\u2026" }
        @started_at = nil
        @last_now = nil
        @running = true
        @expired = false
      end

      # (Re)start the countdown from the top.
      def start
        @started_at = nil
        @last_now = nil
        @running = true
        @expired = false
        self
      end

      def stop
        @running = false
        self
      end

      def expired?
        @expired
      end

      # Whole seconds left (ceil), clamped at 0.
      def remaining
        return @seconds.ceil if @started_at.nil? || @last_now.nil?

        [@seconds - (@last_now - @started_at), 0].max.ceil
      end

      def preferred_height(_width)
        1
      end

      def tick(now)
        @last_now = now
        return unless @running

        @started_at ||= now
        return if @expired

        return unless now - @started_at >= @seconds

        @expired = true
        @running = false
        @on_expire&.call(self)
      end

      def render(window)
        return unless @visible && @rect

        text = @format.call(remaining).to_s[0, @rect.width]
        window.setpos(@rect.y, @rect.x)
        window.attron(theme[:warning]) { window.addstr(text) }
      end
    end
  end
end
