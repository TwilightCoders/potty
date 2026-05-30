# frozen_string_literal: true

module Cursed
  # A named sequence of multiline string frames. Pure data — holds no
  # curses state and no timing state; an Animator drives playback.
  #
  # Each frame is a multiline string. Lines may differ in length and a
  # frame may contain trailing blank lines (preserved via split("\n", -1)).
  class Sprite
    attr_reader :name, :frames, :fps, :mode

    # name   - identifier used to select this sprite on an Animator
    # frames - array of multiline strings, one per animation frame
    # fps    - default playback rate in frames per second
    # mode   - :loop (wrap forever) or :once (stop on the last frame)
    def initialize(name, frames:, fps: 8, mode: :loop)
      raise ArgumentError, 'frames must not be empty' if frames.nil? || frames.empty?
      raise ArgumentError, "mode must be :loop or :once, got #{mode.inspect}" unless %i[loop once].include?(mode)

      @name = name.to_sym
      @frames = frames.dup.freeze
      @fps = fps
      @mode = mode
    end

    def frame_count
      @frames.size
    end

    def frame(index)
      @frames[index]
    end

    # Lines of a frame, preserving trailing blank lines.
    def frame_lines(index)
      (@frames[index] || '').split("\n", -1)
    end

    # Rows in the tallest frame.
    def height
      @frames.map { |f| f.split("\n", -1).size }.max
    end

    # Columns in the widest line across all frames.
    def width
      @frames.flat_map { |f| f.split("\n", -1).map(&:length) }.max
    end
  end
end
