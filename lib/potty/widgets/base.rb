# frozen_string_literal: true

require_relative '../events'

module Potty
  module Widgets
    # Base class for all widgets
    class Base
      include Events

      attr_accessor :rect, :parent, :focused
      attr_reader :app

      def initialize(app)
        @app = app
        @rect = nil
        @parent = nil
        @focused = false
        @visible = true
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
    end
  end
end
