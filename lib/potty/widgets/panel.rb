# frozen_string_literal: true

require_relative 'container'
require_relative '../border'

module Potty
  module Widgets
    # A bordered, optionally titled container. Stacks its children
    # vertically inside a one-cell border frame.
    class Panel < Container
      attr_accessor :title, :style, :color

      def initialize(app, title: nil, style: :single, color: :normal, spacing: 0)
        super(app, spacing: spacing)
        @title = title
        @style = style
        @color = color
      end

      def preferred_height(width)
        inner_w = [width - 2, 0].max
        inner = if @children.empty?
                  0
                else
                  @children.sum { |c| c.preferred_height(inner_w) } + @spacing * (@children.size - 1)
                end
        inner + 2 # top + bottom border
      end

      def layout_children
        inner = Layout::Rect.new(
          @rect.x + 1,
          @rect.y + 1,
          [@rect.width - 2, 0].max,
          [@rect.height - 2, 0].max
        )
        rects = Layout.stack(inner, @children, spacing: @spacing)
        @children.zip(rects).each { |child, rect| child.layout(rect) }
      end

      def render(window)
        return unless @visible && @rect

        Border.draw(window, @rect, style: @style, attr: theme[@color], title: @title)
        super # render children inside the frame
      end
    end
  end
end
