# frozen_string_literal: true

require 'curses'

module Cursed
  # Theme system for colors and styling
  class Theme
    attr_reader :colors

    # -1 means "the terminal's own default colour" (transparent), enabled by
    # use_default_colors. Body text uses default fg AND bg so cursed inherits
    # whatever theme the user runs — readable on dark or light terminals
    # without us guessing. Only deliberate highlights (selection, header,
    # status bar) carry an explicit background.
    DEFAULT = -1

    PAIRS = {
      normal:     [DEFAULT,                 DEFAULT],
      selected:   [::Curses::COLOR_BLACK,   ::Curses::COLOR_GREEN],
      disabled:   [8,                       DEFAULT], # Bright black, transparent
      success:    [::Curses::COLOR_GREEN,   DEFAULT],
      error:      [::Curses::COLOR_RED,     DEFAULT],
      warning:    [::Curses::COLOR_YELLOW,  DEFAULT],
      info:       [::Curses::COLOR_CYAN,    DEFAULT],
      dim:        [8,                       DEFAULT], # Bright black
      header:     [::Curses::COLOR_WHITE,   ::Curses::COLOR_BLUE],
      status:     [::Curses::COLOR_BLACK,   ::Curses::COLOR_CYAN]
    }.freeze

    # Pass a palette hash ({ name => [fg, bg] }) to override or extend the
    # defaults — Application.new(theme: Theme.new(accent: [..]))
    def initialize(palette = nil)
      @pairs = palette ? PAIRS.merge(palette) : PAIRS
      @colors = {}
      setup_colors if ::Curses.has_colors?
    end

    def setup_colors
      ::Curses.start_color
      ::Curses.use_default_colors

      @pairs.each_with_index do |(name, (fg, bg)), idx|
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
