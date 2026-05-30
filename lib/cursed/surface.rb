# frozen_string_literal: true

module Cursed
  # Abstract render target. Widgets draw against a Surface (setpos / addstr /
  # attron) and the concrete subclass decides how that reaches the terminal:
  # CursesSurface paints a curses screen; InlineSurface writes ANSI to stdout.
  # The component tree describes *what*; the surface decides *how*.
  class Surface
    # [rows, cols] of the drawable area.
    def size
      raise NotImplementedError
    end

    # Acquire / release the terminal.
    def start; end
    def finalize; end

    # Frame lifecycle: erase the buffer, widgets draw, then present flushes.
    def erase
      raise NotImplementedError
    end

    def setpos(_row, _col)
      raise NotImplementedError
    end

    def addstr(_str)
      raise NotImplementedError
    end

    # Apply a style around the block's draws. Accepts a Cursed::Style or a
    # raw integer (a legacy curses attribute) — see CursesSurface.
    def attron(_style_or_attr)
      yield if block_given?
    end

    def present
      raise NotImplementedError
    end

    # One integer key code, or nil if there was no input this cycle.
    def read_key
      nil
    end
  end
end
