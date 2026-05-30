# frozen_string_literal: true

require 'curses'

module Potty
  # Named key codes, so widget input handling reads in intent rather than
  # magic integers. Special keys resolve through Curses with fallbacks to
  # the conventional ncurses values, for portability across curses builds.
  #
  # (END_ carries a trailing underscore because END is a Ruby keyword.)
  module Keys
    # Control / ASCII
    CTRL_C    = 3
    CTRL_A    = 1
    CTRL_E    = 5
    CTRL_D    = 4
    TAB       = 9
    ENTER     = 10
    RETURN    = 13
    ESC       = 27
    SPACE     = 32
    CTRL_H    = 8
    DEL_ASCII = 127

    def self.const_or(path, fallback)
      Curses::Key.const_defined?(path) ? Curses::Key.const_get(path) : fallback
    end

    # Arrows / navigation (curses-resolved with ncurses fallbacks)
    UP        = const_or(:UP, 259)
    DOWN      = const_or(:DOWN, 258)
    LEFT      = const_or(:LEFT, 260)
    RIGHT     = const_or(:RIGHT, 261)
    HOME      = const_or(:HOME, 262)
    END_      = const_or(:END, 360)
    DELETE    = const_or(:DC, 330)
    BACKSPACE = const_or(:BACKSPACE, 263)
    SHIFT_TAB = const_or(:BTAB, 353)
    RESIZE    = const_or(:RESIZE, 410)

    # Common groupings
    ENTERS     = [ENTER, RETURN].freeze
    BACKSPACES = [DEL_ASCII, CTRL_H, BACKSPACE].freeze

    module_function

    # Normalize a curses #getch result to an integer key code. Ruby's
    # curses returns a String for ordinary printable input and an Integer
    # for control/function keys — normalizing here lets all widget
    # handle_key logic rely on numeric codes. Passes nil (tick timeout)
    # and Integers through unchanged.
    def code(ch)
      return ch unless ch.is_a?(String)
      return nil if ch.empty?

      ch.ord
    end

    def enter?(ch)
      ENTERS.include?(ch)
    end

    def backspace?(ch)
      BACKSPACES.include?(ch)
    end

    def printable?(ch)
      ch.is_a?(Integer) && ch >= SPACE && ch <= DEL_ASCII - 1
    end
  end
end
