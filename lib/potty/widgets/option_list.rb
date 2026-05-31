# frozen_string_literal: true

module Potty
  module Widgets
    # Shared option-list behavior for the single-select RadioGroup and the
    # multi-select CheckboxGroup: a normalized list of { value:, label: }
    # options plus a navigable cursor. The including widget owns the selection
    # semantics (one committed value vs. a set of them); this models only the
    # options and the highlighted row, which both do identically.
    #
    # Expects the includer to maintain @options (set via #normalize) and an
    # integer @cursor.
    module OptionList
      # The normalized options ({ value:, label: } hashes).
      def options
        @options
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
