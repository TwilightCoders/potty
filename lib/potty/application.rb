# frozen_string_literal: true

require 'curses'
require_relative 'theme'
require_relative 'window_manager'
require_relative 'layout'
require_relative 'keys'
require_relative 'surface'
require_relative 'surfaces/curses_surface'
require_relative 'surfaces/inline_surface'

module Potty
  # Main application wrapper: owns the view stack, the tick loop, and a
  # Surface (the render target). Mode picks the surface:
  #   :curses (default) — full-screen curses display, input via getch.
  #   :inline           — N lines redrawn in place under the cursor via ANSI,
  #                        no init_screen, terminal stays cooked (input
  #                        ignored; host drives quit). Good for progress UIs.
  class Application
    attr_reader :theme, :window_manager, :view_stack, :surface

    # When set (milliseconds), the event loop wakes every interval even
    # without input, advancing time-based widgets (Animator, Countdown).
    # Leave nil for a purely blocking, input-driven loop (the default).
    # ~33-50ms gives smooth animation. Required for :inline.
    attr_accessor :tick_interval

    def initialize(mode: :curses, lines: nil, theme: nil, out: $stdout)
      @view_stack = []
      @running = false
      @theme = theme || Theme.new
      @mode = mode
      @lines = lines
      @out = out
      # Kept for back-compat: curses-mode consumers that draw straight to
      # window_manager.stdscr or read its dimensions.
      @window_manager = (mode == :curses ? WindowManager.new : nil)
      @surface = nil
      @tick_interval = nil
    end

    # Start the application with root view
    def run(root_view)
      @surface = build_surface
      @surface.start
      push_view(root_view)
      @running = true
      event_loop
    ensure
      @surface&.finalize
    end

    # View navigation
    def push_view(view)
      @view_stack.last&.deactivate
      @view_stack.push(view)
      view.activate(self)
      refresh_all
    end

    def pop_view
      return if @view_stack.size <= 1

      view = @view_stack.pop
      view.deactivate
      @view_stack.last&.activate(self)
      refresh_all
    end

    def quit
      @running = false
    end

    def refresh_all
      @surface.erase
      current_view&.render
      @surface.present
    end
    alias redraw refresh_all

    # Advance time-based widgets and repaint. Called automatically each
    # event-loop frame; also public so a host that drives its own loop can
    # pump animation/countdowns itself.
    def tick
      current_view&.tick(Time.now)
      refresh_all
    end

    # Suspend the surface for an external process (e.g., shelling out).
    def suspend
      @surface&.finalize
    end

    # Resume after suspension.
    def resume
      @surface&.start
      current_view&.activate(self)
      refresh_all
    end

    private

    def build_surface
      case @mode
      when :inline
        Surfaces::InlineSurface.new(theme: @theme, lines: @lines, tick_interval: @tick_interval || 40, out: @out)
      else
        Surfaces::CursesSurface.new(@window_manager, @theme, tick_interval: @tick_interval)
      end
    end

    def event_loop
      while @running
        ch = @surface.read_key

        case ch
        when nil # tick timeout / no input this cycle
          # fall through to tick
        when Keys::CTRL_C
          raise Interrupt
        when Keys::ESC
          unless current_view&.handle_escape
            pop_view if @view_stack.size > 1
          end
        else
          current_view&.handle_key(ch)
        end

        tick
      end
    end

    def current_view
      @view_stack.last
    end
  end
end
