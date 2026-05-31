# frozen_string_literal: true

module Potty
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

    # The terminal was resized; refresh any cached dimensions. The Application
    # calls this, then re-lays-out the current view. No-op by default.
    def handle_resize; end

    # Force the *next* frame to repaint everything, bypassing damage tracking.
    # Per-frame #erase is normally damage-tracked (cheap, and it avoids
    # strobing animation) — but on a view transition / resize the whole tree
    # changes, and some back-ends (ncurses with wide / multi-byte glyphs) can
    # fail to mark every changed cell, leaving ghost fragments. The Application
    # calls this around push/pop/resume/resize so the next erase clears fully.
    # No-op by default (e.g. InlineSurface already rewrites every row).
    def force_repaint!; end

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

    # Apply a style around the block's draws. Accepts a Potty::Style or a
    # raw integer (a legacy curses attribute) — see CursesSurface.
    def attron(_style_or_attr)
      yield if block_given?
    end

    # Request the hardware text cursor be shown at (row, col) with a shape
    # (:bar / :block / :underline) when the frame is presented. A widget calls
    # this from #render (e.g. TextInput at its caret); the request lives for
    # one frame — #erase clears it, so a frame with no request hides the
    # cursor. Last call wins, which is correct since only the focused widget
    # asks. Shape control is honoured on surfaces that own the byte stream
    # (InlineSurface, via DECSCUSR); CursesSurface falls back to visibility.
    def place_cursor(row, col, shape: :bar)
      @cursor_request = [row, col, shape]
    end

    def present
      raise NotImplementedError
    end

    # One integer key code, or nil if there was no input this cycle.
    def read_key
      nil
    end

    protected

    # The cursor request recorded this frame, or nil. Subclasses realize it
    # during #present and reset it in #erase.
    attr_accessor :cursor_request
  end
end
