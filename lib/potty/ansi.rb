# frozen_string_literal: true

module Potty
  # Resolve a Style to ANSI SGR escape codes. Shared by InlineSurface (which
  # paints a region) and Potty::Mouth (one-off styled lines), so the
  # symbolic-colour -> SGR mapping lives in exactly one place.
  module Ansi
    SGR_FG = {
      default: 39, black: 30, red: 31, green: 32, yellow: 33,
      blue: 34, magenta: 35, cyan: 36, white: 37, bright_black: 90
    }.freeze
    SGR_BG = {
      default: 49, black: 40, red: 41, green: 42, yellow: 43,
      blue: 44, magenta: 45, cyan: 46, white: 47, bright_black: 100
    }.freeze
    RESET = "\e[0m"

    module_function

    def sgr(style)
      return RESET if style.nil?

      codes = []
      codes << 1 if style.bold?
      codes << 4 if style.underline?
      codes << 7 if style.reverse?
      codes << SGR_FG.fetch(style.fg, 39)
      codes << SGR_BG.fetch(style.bg, 49)
      "\e[#{codes.join(';')}m"
    end

    def reset
      RESET
    end
  end
end
