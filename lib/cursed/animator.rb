# frozen_string_literal: true

require_relative 'widgets/base'
require_relative 'sprite'

module Cursed
  # Frame-based animation widget. Holds one or more named Sprites and
  # advances the active one at its fps on each tick. Being a Widget, it
  # composes into a View tree like anything else.
  #
  # Playback is time-driven: tick(now) advances the frame only when enough
  # wall-clock time has elapsed for the active sprite's fps. The Application
  # event loop supplies `now`; tests can supply it too, which makes the whole
  # thing deterministic.
  class Animator < Widgets::Base
    attr_reader :current, :frame_index
    attr_accessor :color, :on_complete, :centered

    def initialize(app, color: :normal, centered: false)
      super(app)
      @sprites = {}
      @current = nil          # active sprite name (Symbol)
      @frame_index = 0
      @last_advance = nil     # Time of the last frame advance
      @playing = false
      @color = color
      @centered = centered
      @on_complete = nil      # called with self when a :once sprite finishes
    end

    # Register a sprite. The first one added becomes active and starts playing.
    def add_sprite(sprite)
      @sprites[sprite.name] = sprite
      play(sprite.name) if @current.nil?
      self
    end
    alias << add_sprite

    def sprite
      @sprites[@current]
    end

    def sprite_names
      @sprites.keys
    end

    # Switch the active sprite and (re)start playback from frame 0.
    # Pass reset: false to keep the current frame index (e.g. crossfade).
    def play(name, reset: true)
      name = name.to_sym
      return self unless @sprites.key?(name)

      @current = name
      if reset
        @frame_index = 0
        @last_advance = nil
      end
      @playing = true
      self
    end

    def stop
      @playing = false
      self
    end

    def resume
      @playing = true
      self
    end

    def playing?
      @playing
    end

    def preferred_height(_width)
      sprite ? sprite.height : 0
    end

    def tick(now)
      return unless @playing && sprite

      @last_advance ||= now
      frame_duration = 1.0 / sprite.fps
      elapsed = now - @last_advance
      return if elapsed < frame_duration

      # Catch up if the loop ran slow, but never overshoot a :once endpoint.
      steps = (elapsed / frame_duration).floor
      @last_advance += steps * frame_duration
      advance(steps)
    end

    def render(window)
      return unless @visible && @rect && sprite

      attr = theme[@color]
      sprite.frame_lines(@frame_index).each_with_index do |line, row|
        y = @rect.y + row
        break if y >= @rect.y + @rect.height

        x = @rect.x
        x += [(@rect.width - line.length) / 2, 0].max if @centered
        clipped = line[0, @rect.width] || ''
        window.setpos(y, x)
        window.attron(attr) { window.addstr(clipped) }
      end
    end

    private

    def advance(steps)
      case sprite.mode
      when :once
        @frame_index += steps
        if @frame_index >= sprite.frame_count - 1
          @frame_index = sprite.frame_count - 1
          @playing = false
          @on_complete&.call(self)
        end
      else # :loop
        @frame_index = (@frame_index + steps) % sprite.frame_count
      end
    end
  end
end
