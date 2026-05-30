# frozen_string_literal: true

require 'curses'

module Potty
  # Manages curses window lifecycle and refresh coordination
  class WindowManager
    attr_reader :stdscr, :max_y, :max_x

    def initialize
      @windows = {}
      @stdscr = nil
    end

    # Called during application setup
    def setup(stdscr)
      @stdscr = stdscr
      update_dimensions
    end

    def update_dimensions
      @max_y, @max_x = @stdscr.maxy, @stdscr.maxx
    end

    # Create a new window
    def create_window(name, height, width, y, x)
      win = ::Curses::Window.new(height, width, y, x)
      @windows[name] = win
      win
    end

    # Get existing window
    def get_window(name)
      @windows[name]
    end

    # Destroy window
    def destroy_window(name)
      @windows[name]&.close
      @windows.delete(name)
    end

    # Refresh all windows efficiently
    def refresh_all
      @stdscr.noutrefresh
      @windows.values.each(&:noutrefresh)
      ::Curses.doupdate
    end

    def clear_all
      @stdscr.clear
      @windows.values.each(&:clear)
    end
  end
end
