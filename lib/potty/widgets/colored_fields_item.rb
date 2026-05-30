# frozen_string_literal: true

require_relative 'list_item'

module Potty
  module Widgets
    # Generic multi-color list item
    # Takes an array of segments, each with text and color, and renders them inline
    #
    # Usage:
    #   item = ColoredFieldsItem.new(
    #     fields: [
    #       { text: "[M]", color: :success },
    #       { text: " " },
    #       { text: "[0]", color: :dim },
    #       { text: " /path/to/backup", color: :normal }
    #     ],
    #     value: some_object
    #   ) { |item| handle_activation(item) }
    #
    class ColoredFieldsItem < ActionItem
      attr_reader :fields

      def initialize(fields:, value: nil, &action)
        @fields = fields
        super("", value: value, &action)
      end

      def render_custom(window, theme, max_width)
        remaining = max_width
        @fields.each do |field|
          break if remaining <= 0

          text = field[:text] || ""
          color = field[:color]
          bold = field[:bold] || false

          text = text[0, remaining]

          if color
            attr = bold ? theme.attr(color, bold: true) : theme[color]
            window.attron(attr) do
              window.addstr(text)
            end
          else
            window.addstr(text)
          end

          remaining -= text.length
        end

        true
      end
    end
  end
end
