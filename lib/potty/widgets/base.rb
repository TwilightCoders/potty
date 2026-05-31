# frozen_string_literal: true

require_relative '../events'
require_relative '../layout'
require_relative '../border'
require_relative '../focus_style'

module Potty
  module Widgets
    # Base class for all widgets
    class Base
      include Events

      attr_accessor :rect, :parent, :focused
      attr_reader :app

      # Per-widget focus/chrome override. When nil, the widget inherits the
      # Theme's focus_style (the global "stylesheet rule"). See FocusStyle.
      attr_writer :focus_style

      def initialize(app)
        @app = app
        @rect = nil
        @content_rect = nil
        @parent = nil
        @focused = false
        @visible = true
        @focus_style = nil
      end

      # Lifecycle
      def activate
        # Override in subclasses
      end

      def deactivate
        # Override in subclasses
      end

      # Layout
      def preferred_height(width)
        1  # Default to single line
      end

      def layout(rect)
        @rect = rect
        @content_rect = compute_content_rect(rect)
        on_layout
      end

      def on_layout
        # Override for custom layout logic
      end

      # Rendering
      def render(window)
        return unless @visible && @rect
        # Override in subclasses
      end

      # Time-based update hook. Called once per event-loop frame when the
      # Application has a tick_interval set. `now` is a single Time read
      # shared across all widgets in the frame (so playback stays in sync
      # and is deterministic to unit-test). Override in time-driven widgets
      # such as Animator and Countdown.
      def tick(now)
        # Override in time-driven subclasses
      end

      # Input
      def handle_key(ch)
        false  # Return true if handled
      end

      def handle_escape
        false  # Return true if handled
      end

      # Focus
      def can_focus?
        false  # Override in interactive widgets
      end

      def focus
        @focused = true
        on_focus
        emit(:focus, self)
      end

      def blur
        @focused = false
        on_blur
        emit(:blur, self)
      end

      def on_focus; end
      def on_blur; end

      # Visibility
      def visible?
        @visible
      end

      def show
        @visible = true
        self
      end

      def hide
        @visible = false
        self
      end

      def visible=(flag)
        flag ? show : hide
      end

      # Helpers
      def theme
        @app.theme
      end

      # --- Focus chrome (potty's `:focus` stylesheet) -----------------------
      #
      # The resolved FocusStyle: a per-widget override, else the Theme's, else
      # none. Guarded so widgets exercised with a bare stand-in app (specs that
      # only test handle_key) never blow up reaching for a theme.
      def focus_style
        return @focus_style if @focus_style

        t = (@app.respond_to?(:theme) ? @app.theme : nil)
        (t.respond_to?(:focus_style) ? t.focus_style : nil) || FocusStyle.none
      end

      # The rect a widget draws its *content* into — the outer rect minus any
      # chrome insets (border + gutter marker). Equals @rect when there's no
      # chrome (the default), so widgets that draw to content_rect are
      # backward compatible. Chrome is reserved for focusable widgets only, so
      # a global boxed style never insets a Label/StatusBar.
      def content_rect
        @content_rect || @rect
      end

      # Extra rows the border adds to a widget's height. Add this to a
      # focusable widget's intrinsic preferred_height when it can be boxed.
      def chrome_height
        chrome? && focus_style.bordered? ? 2 : 0
      end

      # Draw the focus chrome (border + gutter marker) onto the window. Call at
      # the top of a focusable widget's #render, then draw content into
      # #content_rect. No-op without chrome or a rect.
      def draw_focus_chrome(window)
        return unless chrome? && @rect

        fs = focus_style
        if fs.bordered?
          style = fs.border_for(@focused)
          color = @focused ? fs.focus_color : fs.border_color
          Border.draw(window, @rect, style: style, attr: theme.style(color)) if style
        end

        return unless @focused && fs.marker?

        cr = content_rect
        window.setpos(cr.y, cr.x - fs.marker_width)
        window.attron(theme.style(fs.focus_color)) { window.addstr(fs.marker) }
      end

      private

      # Chrome applies to focusable widgets only (it's a focus stylesheet) and
      # only when the resolved style actually carries chrome.
      def chrome?
        can_focus? && focus_style.chrome?
      end

      def compute_content_rect(rect)
        return rect unless rect && chrome?

        fs = focus_style
        x = rect.x
        y = rect.y
        w = rect.width
        h = rect.height
        if fs.bordered?
          x += 1
          y += 1
          w -= 2
          h -= 2
        end
        m = fs.marker_width
        if m.positive?
          x += m
          w -= m
        end
        Layout::Rect.new(x, y, [w, 0].max, [h, 0].max)
      end
    end
  end
end
