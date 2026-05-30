# frozen_string_literal: true

require_relative '../sprite'

module Cursed
  module Sprites
    # Tiny demo sprites that exercise the Animator API out of the box.
    # These are NOT the claudepilot pilot - that mascot lives in the
    # consuming app. They exist so the primitive has something to show and
    # so consumers have a copy-paste template.
    module Sample
      module_function

      # Looping braille spinner. Single-cell, good for inline "busy" hints.
      def spinner
        Sprite.new(:spinner,
                   frames: ["\u280B", "\u2819", "\u2839", "\u2838", "\u283C",
                            "\u2834", "\u2826", "\u2827", "\u2807", "\u280F"],
                   fps: 12, mode: :loop)
      end

      # A little plane taxiing across the field, played once.
      def plane
        Sprite.new(:plane,
                   frames: [
                     "\u2708        ",
                     "  \u2708      ",
                     "    \u2708    ",
                     "      \u2708  ",
                     "        \u2708"
                   ],
                   fps: 6, mode: :once)
      end
    end
  end
end
