# frozen_string_literal: true

require 'curses'

module Cursed
  # Theme system for colors and styling
  class Theme
    attr_reader :colors

    PAIRS = {
      normal:     [::Curses::COLOR_WHITE,   ::Curses::COLOR_BLACK],
      selected:   [::Curses::COLOR_BLACK,   ::Curses::COLOR_GREEN],
      disabled:   [::Curses::COLOR_BLACK,   ::Curses::COLOR_BLACK],
      success:    [::Curses::COLOR_GREEN,   ::Curses::COLOR_BLACK],
      error:      [::Curses::COLOR_RED,     ::Curses::COLOR_BLACK],
      warning:    [::Curses::COLOR_YELLOW,  ::Curses::COLOR_BLACK],
      info:       [::Curses::COLOR_CYAN,    ::Curses::COLOR_BLACK],
      dim:        [8,                       ::Curses::COLOR_BLACK], # Bright black
      header:     [::Curses::COLOR_WHITE,   ::Curses::COLOR_BLUE],
      status:     [::Curses::COLOR_BLACK,   ::Curses::COLOR_CYAN]
    }.freeze

    def initialize
      @colors = {}
      setup_colors if ::Curses.has_colors?
    end

    def setup_colors
      ::Curses.start_color
      ::Curses.use_default_colors

      PAIRS.each_with_index do |(name, (fg, bg)), idx|
        pair_num = idx + 1
        ::Curses.init_pair(pair_num, fg, bg)
        @colors[name] = ::Curses.color_pair(pair_num)
      end
    end

    def [](name)
      @colors[name] || @colors[:normal] || 0
    end

    # Combine color with attributes
    def attr(name, bold: false, underline: false)
      attr = self[name]
      attr |= ::Curses::A_BOLD if bold
      attr |= ::Curses::A_UNDERLINE if underline
      attr
    end
  end
end
