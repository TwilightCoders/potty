# frozen_string_literal: true

require 'curses'
require_relative 'style'

module Cursed
  # Theme maps semantic names to colours, and speaks two dialects:
  #
  #   theme.style(:info)  => a Style (symbolic, render-target-agnostic) —
  #                          the path Surfaces resolve, for curses OR inline.
  #   theme[:info]        => a curses attribute integer (a colour pair) —
  #                          back-compat for code that draws straight to a
  #                          Curses window. Only meaningful once curses is up.
  #
  # The symbolic PALETTE is the source of truth; the curses pairs are derived
  # from it in setup_colors, so the two dialects never drift.
  class Theme
    # Symbolic colour names -> curses colour numbers (-1 = terminal default).
    COLORS = {
      default: -1,
      black: ::Curses::COLOR_BLACK,   red: ::Curses::COLOR_RED,
      green: ::Curses::COLOR_GREEN,   yellow: ::Curses::COLOR_YELLOW,
      blue: ::Curses::COLOR_BLUE,     magenta: ::Curses::COLOR_MAGENTA,
      cyan: ::Curses::COLOR_CYAN,     white: ::Curses::COLOR_WHITE,
      bright_black: 8
    }.freeze

    # name -> { fg:, bg: } in symbolic colours. Body text inherits the
    # terminal's own colours (:default) so cursed blends into any theme;
    # only deliberate highlights carry an explicit background.
    PALETTE = {
      normal:   { fg: :default,      bg: :default },
      selected: { fg: :black,        bg: :green },
      disabled: { fg: :bright_black, bg: :default },
      success:  { fg: :green,        bg: :default },
      error:    { fg: :red,          bg: :default },
      warning:  { fg: :yellow,       bg: :default },
      info:     { fg: :cyan,         bg: :default },
      dim:      { fg: :bright_black, bg: :default },
      header:   { fg: :white,        bg: :blue },
      status:   { fg: :black,        bg: :cyan }
    }.freeze

    attr_reader :palette, :colors

    # Pass a partial palette ({ name => { fg:, bg: } }) to override entries.
    def initialize(palette = nil)
      @palette = palette ? PALETTE.merge(palette) : PALETTE
      @colors = {}
      setup_colors if ::Curses.has_colors?
    end

    # Allocate a curses colour pair per palette entry (curses mode only).
    def setup_colors
      ::Curses.start_color
      ::Curses.use_default_colors
      @palette.each_with_index do |(name, c), idx|
        pair = idx + 1
        ::Curses.init_pair(pair, COLORS.fetch(c[:fg], -1), COLORS.fetch(c[:bg], -1))
        @colors[name] = ::Curses.color_pair(pair)
      end
    end

    # Semantic style — symbolic colours + attributes, resolved by a Surface.
    def style(name, bold: false, underline: false, reverse: false)
      c = @palette[name] || @palette[:normal]
      Style.new(fg: c[:fg], bg: c[:bg], bold: bold, underline: underline, reverse: reverse)
    end

    # Curses attribute integer (back-compat for direct-to-window drawing).
    def [](name)
      @colors[name] || @colors[:normal] || 0
    end

    def attr(name, bold: false, underline: false)
      a = self[name]
      a |= ::Curses::A_BOLD if bold
      a |= ::Curses::A_UNDERLINE if underline
      a
    end
  end
end
