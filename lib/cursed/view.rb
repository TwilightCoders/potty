# frozen_string_literal: true

require_relative 'layout'
require_relative 'keys'

module Cursed
  # Base class for views
  class View
    attr_reader :app, :widgets

    def initialize(app)
      @app = app
      @widgets = []
      @focused_index = 0
      build_layout
    end

    def activate(app)
      @app = app
      on_activate
      layout_widgets
    end

    def deactivate
      on_deactivate
    end

    def on_activate; end
    def on_deactivate; end

    # Override to build widget tree
    def build_layout
      # Override in subclasses
    end

    def layout_widgets
      max_y, max_x = @app.window_manager.max_y, @app.window_manager.max_x
      container = Layout::Rect.new(0, 0, max_x, max_y)

      # Simple stack layout with spacing
      rects = Layout.stack(container, @widgets, spacing: 1)
      @widgets.zip(rects).each do |widget, rect|
        widget.layout(rect)
      end
    end

    def render
      stdscr = @app.window_manager.stdscr
      # erase (not clear) so doupdate only repaints changed cells — clear
      # forces a full-screen redraw and strobes under animation.
      stdscr.erase

      @widgets.each do |widget|
        widget.render(stdscr)
      end
    end

    # Fan a time tick out to top-level widgets. Driven by Application#tick
    # when a tick_interval is set. `now` is one Time read per frame.
    def tick(now)
      @widgets.each { |widget| widget.tick(now) }
    end

    def handle_key(ch)
      # Delegate to focused widget first
      return true if focused_widget&.handle_key(ch)

      # Handle view-level keys
      case ch
      when Keys::TAB
        cycle_focus(1)
        true
      when Keys::SHIFT_TAB
        cycle_focus(-1)
        true
      else
        false
      end
    end

    def handle_escape
      false  # Return true if handled
    end

    protected

    def flash_success(message)
      flash_widget&.show(message, type: :success)
    end

    def flash_error(message)
      flash_widget&.show(message, type: :error)
    end

    def flash_info(message)
      flash_widget&.show(message, type: :info)
    end

    def flash_widget
      @widgets.find { |w| w.is_a?(Widgets::FlashMessage) }
    end

    private

    # Focusable leaves in visual order, recursing into containers so a
    # nested layout (VBox/HBox/Panel) still cycles correctly with Tab.
    def focusable_widgets
      @widgets.flat_map do |w|
        if w.is_a?(Widgets::Container)
          w.focusable_widgets
        elsif w.can_focus?
          [w]
        else
          []
        end
      end
    end

    def cycle_focus(delta)
      focusable = focusable_widgets
      return if focusable.empty?

      current = focusable.index(focused_widget) || 0
      new_index = (current + delta) % focusable.size

      focused_widget&.blur
      focusable[new_index].focus
    end

    def focused_widget
      focusable_widgets.find(&:focused)
    end
  end
end
