# frozen_string_literal: true

require 'curses'
require_relative 'theme'
require_relative 'window_manager'
require_relative 'layout'
require_relative 'keys'
require_relative 'surface'
require_relative 'surfaces/curses_surface'
require_relative 'surfaces/inline_surface'
require_relative 'scheduled_task'

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

    def initialize(mode: :curses, lines: nil, theme: nil, out: $stdout, listen: false, input: $stdin)
      @view_stack = []
      @running = false
      @theme = theme || Theme.new
      @mode = mode
      @lines = lines
      @out = out
      @listen = listen
      @input = input
      # Kept for back-compat: curses-mode consumers that draw straight to
      # window_manager.stdscr or read its dimensions.
      @window_manager = (mode == :curses ? WindowManager.new : nil)
      @surface = nil
      @tick_interval = nil
      @result_handlers = [] # parallels @view_stack: a pop-result callback per pushed view
      @timers = []          # active ScheduledTasks pumped each tick
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
    #
    # Pass `on_result:` to be called back when this view is later popped with a
    # result — the modal pattern: push an editor, get its value back when it
    # closes, without the pusher blocking. The callback runs in the pusher's
    # context after the parent view is live again.
    def push_view(view, on_result: nil)
      @view_stack.last&.deactivate
      @result_handlers.push(on_result)
      @view_stack.push(view)
      view.activate(self)
      # The whole tree changed — force a full repaint so the new (possibly
      # shorter) view can't leave fragments of the old one behind.
      @surface&.force_repaint!
      refresh_all
    end

    # Pop the current view, optionally handing a result back to whoever pushed
    # it (their `on_result:` callback fires with it). A bare pop (e.g. ESC)
    # delivers nil — read as "cancelled" by a modal.
    def pop_view(result = nil)
      return if @view_stack.size <= 1

      view = @view_stack.pop
      handler = @result_handlers.pop
      view.deactivate
      @view_stack.last&.activate(self)
      @surface&.force_repaint!
      refresh_all
      handler&.call(result)
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

    # Run a block once after `after_seconds`, on the tick clock. Returns a
    # ScheduledTask you can #cancel before it fires. Needs a tick_interval (the
    # loop must be ticking). Good for timeouts / auto-actions (e.g. a recovery
    # curtain's auto-restore) without hand-rolling elapsed-time bookkeeping in
    # a view's #tick.
    def schedule(after_seconds, &block)
      task = ScheduledTask.new(after_seconds, block)
      @timers << task
      task
    end

    # Advance time-based widgets and repaint. Called automatically each
    # event-loop frame; also public so a host that drives its own loop can
    # pump animation/countdowns itself. `now` is injectable for deterministic
    # tests; it defaults to a single Time.now read shared across the frame.
    def tick(now = Time.now)
      fire_due_timers(now)
      current_view&.tick(now)
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
      @surface&.force_repaint!
      refresh_all
    end

    private

    def build_surface
      case @mode
      when :inline
        Surfaces::InlineSurface.new(theme: @theme, lines: @lines, tick_interval: @tick_interval || 40,
                                    out: @out, listen: @listen, input: @input)
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
        when Keys::RESIZE
          resize
        else
          current_view&.handle_key(ch)
        end

        tick
      end
    end

    # The terminal was resized: refresh the surface's dimensions and re-lay-out
    # the current view to the new size. The following tick repaints it.
    def resize
      @surface.handle_resize
      @surface.force_repaint! # geometry changed under us — repaint everything
      current_view&.layout_widgets
    end

    # Fire (and drop) any timers due as of `now`; also drops cancelled ones.
    def fire_due_timers(now)
      @timers.reject! { |task| task.tick(now) }
    end

    def current_view
      @view_stack.last
    end
  end
end
