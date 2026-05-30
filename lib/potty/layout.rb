# frozen_string_literal: true

module Potty
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
  end
end
