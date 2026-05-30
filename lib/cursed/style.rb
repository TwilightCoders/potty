# frozen_string_literal: true

module Cursed
  # A semantic, render-target-agnostic description of how to draw text:
  # symbolic colours (:cyan, :default, :bright_black, …) plus attributes.
  # A Surface resolves a Style to concrete output — curses attributes on a
  # CursesSurface, ANSI SGR codes on an InlineSurface — so the same widget
  # renders to either target unchanged.
  Style = Struct.new(:fg, :bg, :bold, :underline, :reverse, keyword_init: true) do
    def bold?      = !!bold
    def underline? = !!underline
    def reverse?   = !!reverse
  end
end
