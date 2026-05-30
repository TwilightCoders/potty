# frozen_string_literal: true

module Cursed
  # Layout engine for positioning and sizing widgets
  class Layout
    # Rectangle representing position and size
    Rect = Struct.new(:x, :y, :width, :height) do
      def to_s
        "Rect(x=#{x}, y=#{y}, w=#{width}, h=#{height})"
      end
    end

    # Vertical stack layout
    def self.stack(container_rect, widgets, spacing: 0)
      y = container_rect.y
      widgets.map do |widget|
        height = widget.preferred_height(container_rect.width)
        rect = Rect.new(container_rect.x, y, container_rect.width, height)
        y += height + spacing
        rect
      end
    end

    # Horizontal split
    def self.split_horizontal(container_rect, ratio: 0.5)
      split_x = container_rect.x + (container_rect.width * ratio).to_i
      left = Rect.new(
        container_rect.x,
        container_rect.y,
        split_x - container_rect.x,
        container_rect.height
      )
      right = Rect.new(
        split_x,
        container_rect.y,
        container_rect.width - (split_x - container_rect.x),
        container_rect.height
      )
      [left, right]
    end

    # Fill available space
    def self.fill(container_rect)
      container_rect.dup
    end
  end
end
