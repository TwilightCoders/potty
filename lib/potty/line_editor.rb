# frozen_string_literal: true

module Potty
  # The single-line text-editing model shared by the TextInput widget and the
  # list InputItem — a string plus a caret, with insert / delete / navigation.
  # Pure logic, no rendering or curses: widgets own how it's drawn and when to
  # fire change events (the mutators return whether the text changed).
  class LineEditor
    attr_reader :text, :cursor
    attr_accessor :max_length

    def initialize(text = '', max_length: nil)
      @text = text.to_s.dup
      @max_length = max_length
      @cursor = @text.length
    end

    def text=(value)
      @text = value.to_s.dup
      @cursor = [@cursor, @text.length].min
    end

    # Mutators return true when the text changed (so callers know to notify).
    def insert(str)
      return false if @max_length && @text.length >= @max_length

      @text.insert(@cursor, str)
      @cursor += str.length
      true
    end

    def backspace
      return false if @cursor.zero?

      @text.slice!(@cursor - 1)
      @cursor -= 1
      true
    end

    def delete_forward
      return false if @cursor >= @text.length

      @text.slice!(@cursor)
      true
    end

    # Caret navigation (no text change).
    def left  = (@cursor = [@cursor - 1, 0].max)
    def right = (@cursor = [@cursor + 1, @text.length].min)
    def home  = (@cursor = 0)
    def to_end = (@cursor = @text.length)
  end
end
