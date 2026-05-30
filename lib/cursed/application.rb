# frozen_string_literal: true

require 'curses'
require_relative 'theme'
require_relative 'window_manager'
require_relative 'layout'
require_relative 'keys'

module Cursed
  # Main curses application wrapper
  # Handles initialization, event loop, and view stack management
  class Application
    attr_reader :theme, :window_manager, :view_stack

    # When set (milliseconds), the event loop wakes every interval even
    # without input, advancing time-based widgets (Animator, Countdown).
    # Leave nil for a purely blocking, input-driven loop (the default).
    # ~33-50ms gives smooth animation.
    attr_accessor :tick_interval

    def initialize(theme: nil)
      @view_stack = []
      @running = false
      @theme = theme || Theme.new
      @window_manager = WindowManager.new
      @tick_interval = nil
    end

    # Start the application with root view
    def run(root_view)
      setup_curses
      push_view(root_view)
      @running = true
      event_loop
    ensure
      cleanup_curses
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
      current_view&.render
      @window_manager.refresh_all
    end
    alias redraw refresh_all

    # Advance time-based widgets and repaint. Called automatically each
    # event-loop frame; also public so a host that drives its own loop can
    # pump animation/countdowns itself.
    def tick
      current_view&.tick(Time.now)
      refresh_all
    end

    # Suspend curses for external process (e.g., shelling out)
    def suspend
      cleanup_curses
    end

    # Resume curses after suspension
    def resume
      setup_curses
      current_view&.activate(self)
      refresh_all
    end

    private

    def setup_curses
      # ncurses waits ESCDELAY ms (default 1000) after a bare ESC to see if
      # it's the start of an escape sequence (arrows send ESC [ A). 100ms is
      # snappy with headroom for sequences split by SSH/tmux latency. The
      # ESCDELAY env var is only honored by newer ncurses (macOS ships an old
      # one that ignores it), so set it both ways; Curses.ESCDELAY= is the
      # path that actually takes on this system.
      ENV['ESCDELAY'] ||= '100'
      @window_manager.setup(::Curses.init_screen)
      ::Curses.ESCDELAY = 100 if ::Curses.respond_to?(:ESCDELAY=)
      ::Curses.curs_set(0)
      ::Curses.noecho
      ::Curses.cbreak
      ::Curses.stdscr.keypad(true)
      # Non-blocking getch when ticking: returns nil after tick_interval ms
      # so the loop can advance animations between keystrokes.
      ::Curses.stdscr.timeout = @tick_interval if @tick_interval
      @theme.setup_colors
    end

    def cleanup_curses
      ::Curses.close_screen
    end

    def event_loop
      while @running
        ch = Keys.code(@window_manager.stdscr.getch)

        case ch
        when nil # tick timeout, no input (only when tick_interval is set)
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
