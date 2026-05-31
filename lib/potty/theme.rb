# frozen_string_literal: true

require 'curses'
require_relative 'style'
require_relative 'focus_style'

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

    # The focus / field-chrome stylesheet rule applied to focusable widgets
    # (border, gutter marker, fill). Defaults to no chrome — opt in here for a
    # global look, or override per widget. See FocusStyle.
    attr_accessor :focus_style

    # Pass a partial palette ({ name => { fg:, bg: } }) to override entries, and
    # optionally a FocusStyle for the global focus look. focus_style is
    # positional (not a keyword) so the legacy `Theme.new(name: {...})` palette
    # call — which slurps a trailing hash into `palette` — keeps working; it's
    # also settable after construction via #focus_style=.
    def initialize(palette = nil, focus_style = nil)
      @palette = palette ? PALETTE.merge(palette) : PALETTE
      # Default to a visible focus affordance (a left-gutter marker) so a form
      # looks like a working app out of the box — you always see where focus
      # is. It's chrome-light and adds no height (the marker lives in a
      # reserved gutter column, no reflow). Pass FocusStyle.none for the bare
      # look, or .boxed / .filled for more.
      @focus_style = focus_style || FocusStyle.gutter
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

    # The style for a row given whether it's the highlighted/selected one — the
    # single home for "selected looks like :selected + bold, the rest :normal".
    # Widgets decide *which* row is selected (mechanical, theirs); the theme
    # decides how selected vs. unselected *looks* (style, here).
    def selection_style(selected)
      selected ? style(:selected, bold: true) : style(:normal)
    end
  end
end
