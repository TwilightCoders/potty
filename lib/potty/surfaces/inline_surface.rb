# frozen_string_literal: true

require 'io/console'
require_relative '../surface'
require_relative '../ansi'
require_relative '../input/decoder'

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
      def initialize(theme:, lines: nil, tick_interval: 40, out: $stdout, listen: false, input: $stdin)
        super()
        @theme = theme
        @rows = [lines || 1, 1].max
        @tick_interval = tick_interval
        @out = out
        @listen = listen
        @input = input
        @cols = detect_cols
        @cursor = [0, 0]
        @cur_style = nil
        @primed = false
        @raw = false
        # Rows the physical terminal cursor currently sits above the bottom
        # of the region (0 = on the last row). Tracked so the next present can
        # walk back to the top regardless of where realize_cursor left it.
        @cursor_up = 0
        @decoder = (Input::Decoder.new if listen)
        @queue = []
        erase
      end

      def size
        [@rows, @cols]
      end

      def start
        @out.write("\e[?25l") # hide cursor
        @out.flush
        enter_raw if @listen
      end

      def finalize
        self.cursor_request = nil
        present                 # freeze the final frame (cursor hidden, at bottom)
        restore_cooked
        @out.write("\e[0 q")    # reset cursor shape to the terminal default
        # Explicit CR+LF: present leaves the cursor at column 0 of the last
        # row, and in raw mode \n alone is a bare line-feed (no column reset),
        # which would indent whatever the host prints next.
        @out.write("\r\n")      # drop below the region, at column 0
        @out.write("\e[?25h")   # restore cursor
        @out.flush
      end

      # Re-detect the terminal width and rebuild the grid. Inline mode has no
      # KEY_RESIZE (no curses), so this isn't auto-driven — a host that traps
      # SIGWINCH can call it; otherwise the width is fixed for the region's
      # (typically brief) lifetime.
      def handle_resize
        @cols = detect_cols
        erase
      end

      def erase
        self.cursor_request = nil
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
          # Walk back to the top row from wherever the cursor was left last
          # frame (realize_cursor may have parked it on an interior row).
          up = (@rows - 1) - @cursor_up
          @out.write("\e[#{up}A") if up.positive?
        else
          @primed = true
        end
        @out.write("\r") # column 0 of the top row

        @rows.times do |i|
          @out.write("\e[2K") # clear the line (already at column 0)
          @out.write(render_row(@cells[i]))
          @out.write("\r")                      # back to column 0
          @out.write("\n") unless i == @rows - 1 # down a row (raw LF keeps col 0)
        end
        # Physical cursor is now at column 0 of the last row.
        @cursor_up = 0
        realize_cursor
        @out.flush
      end

      # In listen mode: drain raw stdin (non-blocking, waiting up to one tick
      # for the first byte), decode to Keys codes, and return them one per
      # call (queueing the rest). Without listening (or off a real TTY): just
      # pace the loop and return nil, leaving input alone. Ctrl-C arrives as a
      # byte the decoder passes through as Keys::CTRL_C; the event loop raises.
      def read_key
        return @queue.shift unless @queue.empty?

        if @raw
          fill_queue
          @queue.shift
        else
          sleep(@tick_interval / 1000.0) if @tick_interval
          nil
        end
      end

      private

      # Move the real cursor to the requested cell and show it in the wanted
      # shape (DECSCUSR), or keep it hidden. Called at the end of present, when
      # the physical cursor is at column 0 of the last row; records how many
      # rows up it ends so the next present can return to the top.
      def realize_cursor
        unless cursor_request
          @out.write("\e[?25l") # keep hidden
          return
        end

        row, col, shape = cursor_request
        up = (@rows - 1) - row
        @out.write("\e[#{up}A") if up.positive?
        @out.write("\e[#{col}C") if col.positive?
        @out.write(decscusr(shape))
        @out.write("\e[?25h") # show
        @cursor_up = up
      end

      # DECSCUSR (CSI Ps SP q) cursor-shape select. Blinking variants read as
      # an active text caret. 1 = block, 3 = underline, 5 = bar (default).
      def decscusr(shape)
        code = case shape
               when :block then 1
               when :underline then 3
               else 5 # :bar
               end
        "\e[#{code} q"
      end

      def enter_raw
        return unless @input.respond_to?(:raw!) && tty_input?

        @input.raw!     # no echo, no canonical, no signal processing
        @raw = true
      end

      def restore_cooked
        return unless @raw

        @input.cooked!
        @raw = false
      end

      def tty_input?
        @input.respond_to?(:tty?) && @input.tty?
      end

      def fill_queue
        seconds = (@tick_interval || 40) / 1000.0
        bytes = +''
        if IO.select([@input], nil, nil, seconds)
          begin
            loop { bytes << @input.read_nonblock(256) }
          rescue IO::WaitReadable, EOFError
            # drained for now
          end
        end
        @queue.concat(@decoder.feed(bytes, Time.now))
      end

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
