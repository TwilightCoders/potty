# frozen_string_literal: true

module Potty
  # Declarative focus / field chrome — potty's `:focus` stylesheet rule.
  #
  # Where `Style` is surface-agnostic *colour*, FocusStyle is surface-agnostic
  # *decoration*: how a focusable widget shows that it's focused, and whether it
  # carries a border. It's pure data; widgets resolve it against the Theme (or a
  # per-widget override) at render time, exactly like CSS `input:focus { … }`
  # applies to the element itself — no wrapper widget needed (that's what
  # Panel/VBox/Container are for, when you want to *group* fields).
  #
  # Every affordance is an independent knob, so they compose:
  #   - border / focus_border : box the field (lit heavier/coloured on focus)
  #   - marker                : a left-gutter indicator drawn when focused
  #   - fill                  : fill the focused field's background
  #
  # Geometry is reserved from the *static* config (is there a border? a
  # marker?), never from focus state — so focusing a widget changes only its
  # appearance, never the layout (no reflow / content jump).
  #
  # The default (FocusStyle.none) carries no chrome, so existing apps render
  # unchanged; opt in by setting one on the Theme (global look) or per widget.
  class FocusStyle
    BORDER_STYLES = %i[single rounded double heavy].freeze

    attr_reader :border, :focus_border, :border_color, :focus_color,
                :marker, :fill, :fill_color

    # border       : box style when unfocused — nil | :single | :rounded | :double | :heavy
    # focus_border : box style when focused (nil falls back to `border`)
    # border_color : semantic palette name for the box, unfocused
    # focus_color  : semantic palette name for the box + marker, focused
    # marker       : string drawn in the left gutter when focused, or nil
    # fill         : fill the focused field's background (mainly TextInput)
    # fill_color   : semantic palette name for the fill
    def initialize(border: nil, focus_border: nil, border_color: :dim,
                   focus_color: :info, marker: nil, fill: false,
                   fill_color: :selected)
      @border = border
      @focus_border = focus_border
      @border_color = border_color
      @focus_color = focus_color
      @marker = marker
      @fill = fill
      @fill_color = fill_color
    end

    # No chrome — the default, fully backward compatible.
    def self.none
      new
    end

    # Lit boxed fields: a box that recolors on focus (dim -> focus colour),
    # keeping the same border weight so the box doesn't visibly thicken. Pass
    # `focus:` (e.g. :heavy) to also change the border style on focus.
    def self.boxed(style: :single, focus: nil, color: :info, dim: :dim)
      new(border: style, focus_border: focus, border_color: dim, focus_color: color)
    end

    # A left-gutter chevron/bar on the focused field, no border.
    def self.gutter(marker: "\u276f ", color: :info)
      new(marker: marker, focus_color: color)
    end

    # The focused field lights up via a background fill, no border.
    def self.filled(color: :selected)
      new(fill: true, fill_color: color)
    end

    # Does this style reserve a border box?
    def bordered?
      !(@border.nil? && @focus_border.nil?)
    end

    # The border style to draw for the given focus state (may be nil = draw
    # nothing, though the inset is still reserved when bordered?).
    def border_for(focused)
      focused ? (@focus_border || @border) : @border
    end

    # Columns the gutter marker reserves on the left.
    def marker_width
      @marker ? @marker.length : 0
    end

    def marker?
      marker_width.positive?
    end

    # Does this style draw any chrome at all (vs. FocusStyle.none)?
    def chrome?
      bordered? || marker?
    end
  end
end
