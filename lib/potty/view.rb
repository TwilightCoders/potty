# frozen_string_literal: true

require_relative 'layout'
require_relative 'keys'

module Potty
  # Base class for views
  class View
    attr_reader :app, :widgets

    def initialize(app)
      @app = app
      @widgets = []
      @focused_index = 0
      @built = false
      # NOTE: build_layout is deferred to the first #activate (below), NOT run
      # here. A View is constructed *before* Application#run builds the Surface,
      # so @app.surface is nil during construction — building layout here means
      # anything reaching for surface.size / theme during build_layout nils out
      # at runtime. Deferring guarantees the surface exists first.
    end

    def activate(app)
      @app = app
      # Build the widget tree on first activation, once the surface exists.
      unless @built
        build_layout
        @built = true
      end
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
      rows, cols = @app.surface.size
      container = Layout::Rect.new(0, 0, cols, rows)

      # Simple stack layout. Override #spacing to pack tighter — inline views
      # in particular want 0 so their height matches the region exactly.
      rects = Layout.stack(container, @widgets, spacing: spacing)
      @widgets.zip(rects).each do |widget, rect|
        widget.layout(rect)
      end
    end

    # Rows of blank space the default layout leaves between top-level widgets.
    # Override to change it (e.g. 0 for a tightly-packed inline region).
    def spacing
      1
    end

    # Draw the widget tree onto the application's surface. The surface frame
    # (erase/present) is owned by Application#refresh_all, so this just paints.
    def render
      surface = @app.surface
      @widgets.each do |widget|
        widget.render(surface)
      end
    end

    # Fan a time tick out to top-level widgets. Driven by Application#tick
    # when a tick_interval is set. `now` is one Time read per frame.
    def tick(now)
      @widgets.each { |widget| widget.tick(now) }
    end

    # NOTE on ESC: the Application's event loop intercepts ESC *upstream* and
    # routes it to #handle_escape, NOT here — so a `when Keys::ESC` branch in
    # this method (or a widget's handle_key) is dead code and will never fire.
    # To react to ESC, override #handle_escape (return true if you handled it;
    # return false to let the Application pop the view stack).
    def handle_key(ch)
      # Delegate to focused widget first
      return true if focused_widget&.handle_key(ch)

      # Handle view-level keys. Enter advances focus like Tab when the
      # focused widget didn't consume it — so a form flows field -> field ->
      # button (where the button finally consumes Enter and fires). A view
      # that wants Enter for itself (e.g. a prompt that submits) intercepts it
      # before delegating to super.
      case ch
      when Keys::TAB, *Keys::ENTERS
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
