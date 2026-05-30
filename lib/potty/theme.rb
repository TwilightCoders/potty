# frozen_string_literal: true

require 'curses'
require_relative 'style'

module Potty
  # Theme maps semantic names to a render-target-agnostic Style (symbolic
  # colours + attributes). It is pure data — it does NOT touch curses. Each
  # Surface resolves a Style to its concrete form (CursesSurface to a colour
  # pair, InlineSurface to ANSI SGR), which is why a single Theme drives both
  # rendering modes and why every widget that asks the theme for an attribute
  # works in either mode with no per-widget special-casing.
  #
  # `style`, `[]`, and `attr` all return a Style — `[]`/`attr` are kept as
  # ergonomic aliases (attr adds bold/underline).
  class Theme
    # Symbolic colour names -> curses colour numbers (-1 = terminal default).
    # Used by CursesSurface when it resolves a Style to a colour pair.
    COLORS = {
      default: -1,
      black: ::Curses::COLOR_BLACK,   red: ::Curses::COLOR_RED,
      green: ::Curses::COLOR_GREEN,   yellow: ::Curses::COLOR_YELLOW,
      blue: ::Curses::COLOR_BLUE,     magenta: ::Curses::COLOR_MAGENTA,
      cyan: ::Curses::COLOR_CYAN,     white: ::Curses::COLOR_WHITE,
      bright_black: 8
    }.freeze

    # name -> { fg:, bg: } in symbolic colours. Body text inherits the
    # terminal's own colours (:default) so potty blends into any theme;
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

    attr_reader :palette

    # Pass a partial palette ({ name => { fg:, bg: } }) to override entries.
    def initialize(palette = nil)
      @palette = palette ? PALETTE.merge(palette) : PALETTE
    end

    # Semantic style — symbolic colours + attributes, resolved by a Surface.
    def style(name, bold: false, underline: false, reverse: false)
      c = @palette[name] || @palette[:normal]
      Style.new(fg: c[:fg], bg: c[:bg], bold: bold, underline: underline, reverse: reverse)
    end

    # Ergonomic aliases — both return a Style, so widgets can use whichever
    # reads best and still render in any mode.
    def [](name)
      style(name)
    end

    def attr(name, bold: false, underline: false)
      style(name, bold: bold, underline: underline)
    end
  end
end
