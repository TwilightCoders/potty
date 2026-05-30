# frozen_string_literal: true

require 'curses'
require_relative '../surface'
require_relative '../theme'
require_relative '../keys'

module Potty
  module Surfaces
    # The default render target: a full-screen curses display. Wraps the
    # WindowManager / stdscr. It resolves a Style to a curses colour pair +
    # attributes (allocating pairs on demand); a raw integer is passed through
    # unchanged, so a host that draws to the surface with its own curses attrs
    # still works.
    class CursesSurface < Surface
      def initialize(window_manager, theme, tick_interval: nil)
        super()
        @wm = window_manager
        @theme = theme
        @tick_interval = tick_interval
        @next_pair = 1
        @pairs = {}
      end

      def start
        # See ESCDELAY notes in Theme/Application history: the env var is only
        # honoured by newer ncurses, so also set it via Curses.ESCDELAY=.
        ENV['ESCDELAY'] ||= '250'
        @wm.setup(::Curses.init_screen)
        ::Curses.ESCDELAY = 250 if ::Curses.respond_to?(:ESCDELAY=)
        ::Curses.curs_set(0)
        ::Curses.noecho
        ::Curses.cbreak
        stdscr.keypad(true)
        stdscr.timeout = @tick_interval if @tick_interval
        if ::Curses.has_colors?
          ::Curses.start_color
          ::Curses.use_default_colors # enables -1 = terminal default
        end
      end

      def finalize
        ::Curses.close_screen
      end

      def size
        [@wm.max_y, @wm.max_x]
      end

      def erase
        stdscr.erase
      end

      def setpos(row, col)
        stdscr.setpos(row, col)
      end

      def addstr(str)
        stdscr.addstr(str)
      end

      def attron(style_or_attr, &block)
        stdscr.attron(curses_attr(style_or_attr), &block)
      end

      def present
        @wm.refresh_all
      end

      def read_key
        Keys.code(stdscr.getch)
      end

      private

      def stdscr
        @wm.stdscr
      end

      def curses_attr(value)
        return value if value.is_a?(Integer) # legacy curses attribute
        return 0 unless value.is_a?(Potty::Style)

        attr = color_pair(value.fg, value.bg)
        attr |= ::Curses::A_BOLD      if value.bold?
        attr |= ::Curses::A_UNDERLINE if value.underline?
        attr |= ::Curses::A_REVERSE   if value.reverse?
        attr
      end

      # Allocate (once) and cache a curses colour pair per (fg, bg) combo the
      # theme's Styles use. The palette is small, so this stays well within
      # the terminal's pair budget.
      def color_pair(fg, bg)
        return 0 unless ::Curses.has_colors?

        @pairs[[fg, bg]] ||= allocate_pair(fg, bg)
      end

      def allocate_pair(fg, bg)
        n = @next_pair
        @next_pair += 1
        ::Curses.init_pair(n, Theme::COLORS.fetch(fg, -1), Theme::COLORS.fetch(bg, -1))
        ::Curses.color_pair(n)
      end
    end
  end
end
