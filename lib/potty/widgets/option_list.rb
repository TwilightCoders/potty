# frozen_string_literal: true

require_relative '../keys'

module Potty
  module Widgets
    # Shared behavior for the single-select RadioGroup and the multi-select
    # CheckboxGroup: a normalized list of { value:, label: } options, a
    # navigable cursor, and the (identical) key handling and row rendering.
    # The including widget supplies only its selection semantics, via two
    # hooks:
    #
    #   commit_at(index)  - act on the option under the cursor (Space/Enter)
    #   row_marker(opt)   - the leading glyph for a row, e.g. "(●)" / "[ ]"
    #
    # Expects the includer (a Widgets::Base subclass) to maintain @options
    # (built via #normalize) and an integer @cursor; it provides everything
    # else — handle_key, draw, move, normalize, index_of.
    module OptionList
      # The normalized options ({ value:, label: } hashes).
      def options
        @options
      end

      def handle_key(ch)
        case ch
        when Keys::UP then move(-1)
        when Keys::DOWN then move(1)
        when Keys::SPACE, *Keys::ENTERS then commit_at(@cursor)
        else return false
        end
        true
      end

      # One row per option, the cursor row highlighted. Base#render has already
      # guarded visibility and painted focus chrome; this just paints content.
      #
      # Each row is left-justified to rect.width so a shorter row replacing
      # a longer one (cursor moved, options updated) doesn't leave the
      # previous row's tail on screen. Mirrors TextInput's ljust pattern;
      # without it, navigating from "all interfaces (0.0.0.0)" to
      # "en0 (192.168.1.42)" leaves ".42)" hanging at the right edge.
      def draw(window)
        rect = content_rect
        @options.each_with_index do |opt, i|
          break if i >= rect.height

          text = +"#{row_marker(opt)} #{opt[:label]}"
          text = text.byteslice(0, rect.width).to_s if text.bytesize > rect.width
          text = text.ljust(rect.width)
          window.setpos(rect.y + i, rect.x)
          window.attron(theme.selection_style(@focused && i == @cursor)) do
            window.addstr(text)
          end
        end
      end

      private

      # Coerce a raw options list into { value:, label: } hashes. A bare value
      # becomes its own value with a stringified label; a Hash supplies an
      # explicit label (falling back to the stringified value).
      def normalize(opts)
        (opts || []).map do |o|
          if o.is_a?(Hash)
            { value: o[:value], label: (o[:label] || o[:value]).to_s }
          else
            { value: o, label: o.to_s }
          end
        end
      end

      # Move the cursor by delta, wrapping at the ends. No-op when empty.
      def move(delta)
        return if @options.empty?

        @cursor = (@cursor + delta) % @options.size
      end

      # Index of the option carrying `value`, or nil.
      def index_of(value)
        @options.index { |o| o[:value] == value }
      end
    end
  end
end
