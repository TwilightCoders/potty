# frozen_string_literal: true

require_relative 'base'
require_relative '../animator'
require_relative '../sprites/sample'

module Potty
  module Widgets
    # Single-line activity indicator: an animated braille spinner, a live
    # mutable label, and a trailing state. While active the glyph is the
    # spinner; complete!(result) freezes it to a fixed glyph and flips the
    # color. Passive (no focus/input). Tick-driven via an internal Animator.
    #
    #   s = Spinner.new(app, label: "daemon - running")
    #   s.label = "daemon - surrendering 16 children"   # live update
    #   s.complete!(:success)   # glyph -> checkmark, color -> :success
    class Spinner < Base
      STATE_GLYPHS = { success: "\u2713", failure: "\u2717", cancelled: "\u23F9" }.freeze
      STATE_COLORS = { success: :success, failure: :error, cancelled: :dim }.freeze

      attr_accessor :label, :prefix
      attr_reader :state, :color

      def initialize(app, label: '', color: :info, prefix: '  ')
        super(app)
        @label = label
        @color = color
        @prefix = prefix
        @state = :active
        @animator = Animator.new(app)
        @animator << Sprites::Sample.spinner
      end

      def active?
        @state == :active
      end

      # Freeze the spinner to a terminal state. Idempotent: only the first
      # call takes effect, so repeated lifecycle events are harmless.
      def complete!(result = :success)
        return self unless active?

        @state = result
        @color = STATE_COLORS.fetch(result, @color)
        @animator.stop
        emit(:complete, result)
        self
      end

      def preferred_height(_width)
        1
      end

      def tick(now)
        @animator.tick(now) if active?
      end

      def draw(window)
        glyph = active? ? current_frame : STATE_GLYPHS.fetch(@state, '?')
        text = truncate("#{@prefix}#{glyph} #{@label}", @rect.width)
        window.setpos(@rect.y, @rect.x)
        # theme.style (not theme[]) so we render in colour on either surface —
        # curses resolves the Style to a pair, inline to ANSI SGR.
        window.attron(theme.style(@color)) { window.addstr(text) }
      end

      private

      def current_frame
        sprite = @animator.sprite
        sprite ? sprite.frame_lines(@animator.frame_index).first : ' '
      end

      def truncate(str, width)
        return str if str.length <= width
        return str[0, width] || '' if width < 2

        "#{str[0, width - 1]}\u2026"
      end
    end
  end
end
