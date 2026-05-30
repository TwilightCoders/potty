# frozen_string_literal: true

require_relative '../surface'
require_relative '../ansi'

module Potty
  module Surfaces
    # Renders an N-line region in place under the cursor — like docker
    # compose / npm / cargo progress — instead of taking over the screen.
    # No init_screen, no alt-screen; the terminal stays in cooked mode, so
    # Ctrl-C behaves normally and input is left alone (passive widgets only).
    #
    # Model: a small cell grid (rows x cols). Widgets draw into it via the
    # same setpos/addstr/attron calls they use on a curses surface; present
    # repaints the region with ANSI (carriage-return + clear-line per row,
    # then cursor back to the top). finalize freezes the last frame and drops
    # the cursor to the line below so the next prompt lands cleanly.
    class InlineSurface < Surface
      def initialize(theme:, lines: nil, tick_interval: 40, out: $stdout)
        super()
        @theme = theme
        @rows = [lines || 1, 1].max
        @tick_interval = tick_interval
        @out = out
        @cols = detect_cols
        @cursor = [0, 0]
        @cur_style = nil
        @primed = false
        erase
      end

      def size
        [@rows, @cols]
      end

      def start
        @out.write("\e[?25l") # hide cursor
        @out.flush
      end

      def finalize
        present                 # freeze the final frame
        @out.write("\n")        # drop below the region
        @out.write("\e[?25h")   # restore cursor
        @out.flush
      end

      def erase
        @cells = Array.new(@rows) { Array.new(@cols) { [' ', nil] } }
      end

      def setpos(row, col)
        @cursor = [row, col]
      end

      def addstr(str)
        row, col = @cursor
        return unless row.between?(0, @rows - 1)

        str.to_s.each_char do |ch|
          break if col >= @cols

          @cells[row][col] = [ch, @cur_style] if col >= 0
          col += 1
        end
        @cursor = [row, col]
      end

      def attron(style)
        prev = @cur_style
        @cur_style = style.is_a?(Potty::Style) ? style : nil
        yield if block_given?
      ensure
        @cur_style = prev
      end

      def present
        if @primed
          @out.write("\e[#{@rows - 1}A") if @rows > 1 # back to the top row
        else
          @primed = true
        end

        @rows.times do |i|
          @out.write("\r\e[2K") # carriage return + clear line
          @out.write(render_row(@cells[i]))
          @out.write("\n") unless i == @rows - 1
        end
        @out.flush
      end

      # Inline mode ignores input; sleeping here gives the loop its tick
      # cadence. Terminal stays cooked, so Ctrl-C raises Interrupt normally.
      def read_key
        sleep(@tick_interval / 1000.0) if @tick_interval
        nil
      end

      private

      def render_row(cells)
        last = cells.rindex { |ch, _| ch != ' ' } || -1
        return '' if last.negative?

        out = +''
        emitted = nil
        (0..last).each do |i|
          ch, style = cells[i]
          if style != emitted
            out << Ansi.sgr(style)
            emitted = style
          end
          out << ch
        end
        out << Ansi::RESET if emitted
        out
      end

      def detect_cols
        return @out.winsize[1] if @out.respond_to?(:winsize) && @out.tty?

        (ENV['COLUMNS'] || 80).to_i
      rescue StandardError
        80
      end
    end
  end
end
