# frozen_string_literal: true

require 'curses'
require_relative '../surface'
require_relative '../theme'
require_relative '../keys'

module Cursed
  module Surfaces
    # The default render target: a full-screen curses display. Wraps the
    # WindowManager / stdscr so existing widgets draw exactly as before.
    #
    # attron accepts EITHER a Cursed::Style (resolved to a colour pair +
    # attributes) OR a raw integer (a legacy curses attribute, passed
    # through). That dual acceptance is what lets un-migrated widgets — and
    # direct-to-window consumers like a host's own paint code — keep working
    # untouched while new widgets go render-target-agnostic.
    class CursesSurface < Surface
      def initialize(window_manager, theme, tick_interval: nil)
        super()
        @wm = window_manager
        @theme = theme
        @tick_interval = tick_interval
        @next_pair = theme.palette.size + 1 # leave 1..N for theme[]'s pairs
        @pairs = nil
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
        @theme.setup_colors if ::Curses.has_colors?
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
        return 0 unless value.is_a?(Cursed::Style)

        attr = color_pair(value.fg, value.bg)
        attr |= ::Curses::A_BOLD      if value.bold?
        attr |= ::Curses::A_UNDERLINE if value.underline?
        attr |= ::Curses::A_REVERSE   if value.reverse?
        attr
      end

      def color_pair(fg, bg)
        return 0 unless ::Curses.has_colors?

        (@pairs ||= seed_pairs)
        @pairs[[fg, bg]] ||= allocate_pair(fg, bg)
      end

      # Reuse the pairs Theme already allocated for its palette combos so we
      # don't burn a second pair on every colour we share with theme[].
      def seed_pairs
        map = {}
        @theme.palette.each { |name, c| map[[c[:fg], c[:bg]]] = @theme[name] }
        map
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
