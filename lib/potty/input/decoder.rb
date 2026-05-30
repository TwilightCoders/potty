# frozen_string_literal: true

require_relative '../keys'

module Potty
  module Input
    # Turns a raw terminal byte stream into Keys codes. In curses mode the
    # library gets this for free via keypad(true); inline "listen" mode reads
    # raw bytes, so we decode here — and crucially we emit the *same* integer
    # codes curses would, so every widget's handle_key works unchanged in
    # either mode.
    #
    # Printable/control bytes pass straight through as codes. Escape sequences
    # (ESC [ A, ESC O P, ESC [ 3 ~, …) map to Keys::UP / DELETE / etc. A lone
    # ESC is ambiguous — it may begin a sequence — so it's held until either
    # more bytes complete a sequence, or enough time passes (escape_timeout)
    # that we resolve it to a bare ESC. Same heuristic curses runs internally
    # via ESCDELAY; here it's ours.
    #
    # Usage (driven by the inline loop each tick):
    #   keys = decoder.feed(bytes_available, now)   # bytes may be ""
    #   keys.each { |code| view.handle_key(code) }
    class Decoder
      # Escape sequence (the bytes after ESC) -> Keys code.
      SEQUENCES = {
        '[A' => Keys::UP,    'OA' => Keys::UP,
        '[B' => Keys::DOWN,  'OB' => Keys::DOWN,
        '[C' => Keys::RIGHT, 'OC' => Keys::RIGHT,
        '[D' => Keys::LEFT,  'OD' => Keys::LEFT,
        '[H' => Keys::HOME,  'OH' => Keys::HOME,  '[1~' => Keys::HOME,
        '[F' => Keys::END_,  'OF' => Keys::END_,  '[4~' => Keys::END_,
        '[3~' => Keys::DELETE,
        '[Z' => Keys::SHIFT_TAB
      }.freeze

      # Longest escape body we might still be completing (e.g. "[3~").
      MAX_SEQ = SEQUENCES.keys.map(&:length).max

      def initialize(escape_timeout: 0.25)
        @escape_timeout = escape_timeout
        @buffer = +''
        @esc_at = nil
      end

      # Append newly-read bytes (may be empty) and return the key codes that
      # can be resolved now. `now` is a monotonic-ish time used only for the
      # bare-ESC timeout; pass Time.now from the loop (and in tests).
      def feed(bytes, now)
        @buffer << bytes.to_s
        codes = []
        while (code = take(now))
          codes << code
        end
        codes
      end

      private

      # Pull the next resolvable key from the buffer, or nil if we must wait.
      def take(now)
        return nil if @buffer.empty?

        if @buffer.getbyte(0) == Keys::ESC
          take_escape(now)
        else
          @esc_at = nil
          byte = @buffer.getbyte(0)
          @buffer.slice!(0)
          byte
        end
      end

      def take_escape(now)
        body = @buffer[1..] || ''

        # A complete, recognized sequence?
        if (seq = SEQUENCES.keys.find { |s| body.start_with?(s) })
          @buffer.slice!(0, 1 + seq.length)
          @esc_at = nil
          return SEQUENCES[seq]
        end

        # Still possibly the beginning of one? Hold and wait for more bytes,
        # unless we've waited past the escape timeout — then it's a bare ESC.
        if could_complete?(body)
          @esc_at ||= now
          return nil unless timed_out?(now)
        end

        # Bare ESC (lone, timed out, or ESC followed by an unrelated byte).
        @buffer.slice!(0)
        @esc_at = nil
        Keys::ESC
      end

      # Could `body` (bytes after ESC) still grow into a known sequence?
      def could_complete?(body)
        return true if body.empty? && incomplete_possible?
        return false if body.length >= MAX_SEQ

        SEQUENCES.keys.any? { |s| s.start_with?(body) && s != body }
      end

      def incomplete_possible?
        true # a lone ESC could begin any sequence
      end

      def timed_out?(now)
        @esc_at && (now - @esc_at) >= @escape_timeout
      end
    end
  end
end
