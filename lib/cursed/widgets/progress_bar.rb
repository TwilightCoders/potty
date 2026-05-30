# frozen_string_literal: true

module Cursed
  module Widgets
    # High-fidelity progress bar using Unicode block elements
    # Provides 8x more granularity than simple filled/empty characters
    # Pure string rendering - works in both curses and TTY contexts
    class ProgressBar
      BLOCKS = [
        ' ',
        "\u258F",  # 1/8
        "\u258E",  # 2/8
        "\u258D",  # 3/8
        "\u258C",  # 4/8
        "\u258B",  # 5/8
        "\u258A",  # 6/8
        "\u2589",  # 7/8
        "\u2588"   # Full
      ].freeze

      attr_reader :width

      def initialize(width: 20)
        @width = width
      end

      # Generate progress bar string
      # @param progress [Float] Progress from 0.0 to 1.0
      # @return [String] The rendered progress bar
      def render(progress)
        progress = [[progress, 0.0].max, 1.0].min

        total_units = @width * 8
        filled_units = (progress * total_units).round

        full_blocks = filled_units / 8
        partial_eighths = filled_units % 8

        bar = BLOCKS[8] * full_blocks

        if full_blocks < @width
          bar += BLOCKS[partial_eighths]
          bar += ' ' * (@width - full_blocks - 1)
        end

        bar
      end

      # Render with brackets
      def render_with_brackets(progress)
        "[#{render(progress)}]"
      end
    end
  end
end
