# frozen_string_literal: true

require 'curses'

module Potty
  # Holds the curses stdscr and screen dimensions, and batches the
  # refresh (noutrefresh + doupdate). Backs CursesSurface.
  class WindowManager
    attr_reader :stdscr, :max_y, :max_x

    def initialize
      @stdscr = nil
    end

    # Called during application setup.
    def setup(stdscr)
      @stdscr = stdscr
      update_dimensions
    end

    def update_dimensions
      @max_y = @stdscr.maxy
      @max_x = @stdscr.maxx
    end

    # Flush buffered drawing to the screen.
    def refresh_all
      @stdscr.noutrefresh
      ::Curses.doupdate
    end
  end
end
