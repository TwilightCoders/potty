# frozen_string_literal: true

require_relative 'base'
require_relative '../layout'

module Cursed
  module Widgets
    # A widget that holds child widgets and lays them out within its own
    # rect. Render, tick, and focus traversal recurse into children, so a
    # View's flat `@widgets` array can now contain arbitrarily nested
    # structure (a VBox of HBoxes of fields, etc.) while the View itself
    # stays unchanged.
    #
    # Subclasses implement `layout_children` (assign each child a rect) and
    # `preferred_height`.
    class Container < Base
      attr_reader :children

      def initialize(app, spacing: 0)
        super(app)
        @children = []
        @spacing = spacing
      end

      def add(*widgets)
        widgets.flatten.each do |w|
          w.parent = self
          @children << w
        end
        self
      end
      alias << add

      # Focusable leaf descendants, in visual order (depth-first).
      def focusable_widgets
        @children.flat_map do |child|
          if child.is_a?(Container)
            child.focusable_widgets
          elsif child.can_focus?
            [child]
          else
            []
          end
        end
      end

      def on_layout
        layout_children
      end

      # Override in subclasses.
      def layout_children
        # no-op
      end

      def render(window)
        return unless @visible && @rect

        @children.each { |child| child.render(window) if child.visible? }
      end

      def tick(now)
        @children.each { |child| child.tick(now) }
      end
    end

    # Vertical stack — children top to bottom, each at its preferred height.
    class VBox < Container
      def preferred_height(width)
        return 0 if @children.empty?

        @children.sum { |c| c.preferred_height(width) } + @spacing * (@children.size - 1)
      end

      def layout_children
        rects = Layout.stack(@rect.dup, @children, spacing: @spacing)
        @children.zip(rects).each { |child, rect| child.layout(rect) }
      end
    end

    # Horizontal row — children share the width in equal columns (the last
    # absorbs rounding), each spanning the full height.
    class HBox < Container
      def preferred_height(width)
        return 0 if @children.empty?

        @children.map { |c| c.preferred_height(child_width(width)) }.max
      end

      def layout_children
        n = @children.size
        return if n.zero?

        base = child_width(@rect.width)
        x = @rect.x
        @children.each_with_index do |child, i|
          w = i == n - 1 ? (@rect.x + @rect.width - x) : base
          child.layout(Layout::Rect.new(x, @rect.y, w, @rect.height))
          x += w + @spacing
        end
      end

      private

      def child_width(width)
        n = @children.size
        return width if n.zero?

        [(width - @spacing * (n - 1)) / n, 1].max
      end
    end
  end
end
