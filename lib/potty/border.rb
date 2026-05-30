# frozen_string_literal: true

module Potty
  # Box-drawing helper shared by any widget that needs a frame (List,
  # Panel, Modal, etc.) instead of each one hand-rolling corner glyphs.
  module Border
    STYLES = {
      single:  { tl: "\u250C", tr: "\u2510", bl: "\u2514", br: "\u2518", h: "\u2500", v: "\u2502" },
      rounded: { tl: "\u256D", tr: "\u256E", bl: "\u2570", br: "\u256F", h: "\u2500", v: "\u2502" },
      double:  { tl: "\u2554", tr: "\u2557", bl: "\u255A", br: "\u255D", h: "\u2550", v: "\u2551" },
      heavy:   { tl: "\u250F", tr: "\u2513", bl: "\u2517", br: "\u251B", h: "\u2501", v: "\u2503" }
    }.freeze

    module_function

    # Draw a border around rect on window. `attr` is a resolved curses
    # attribute (e.g. theme[:dim]); `title`, if given, is centered on the
    # top edge.
    def draw(window, rect, style: :single, attr: 0, title: nil)
      return if rect.width < 2 || rect.height < 2

      s = STYLES[style] || STYLES[:single]
      inner = rect.width - 2

      window.attron(attr) do
        window.setpos(rect.y, rect.x)
        window.addstr(s[:tl] + s[:h] * inner + s[:tr])

        (1...(rect.height - 1)).each do |dy|
          window.setpos(rect.y + dy, rect.x)
          window.addstr(s[:v])
          window.setpos(rect.y + dy, rect.x + rect.width - 1)
          window.addstr(s[:v])
        end

        window.setpos(rect.y + rect.height - 1, rect.x)
        window.addstr(s[:bl] + s[:h] * inner + s[:br])
      end

      draw_title(window, rect, title, attr, inner) if title && !title.to_s.empty?
    end

    def draw_title(window, rect, title, attr, inner)
      label = " #{title} "
      label = label[0, inner] || '' if label.length > inner
      x = rect.x + 1 + [(inner - label.length) / 2, 0].max
      window.setpos(rect.y, x)
      window.attron(attr) { window.addstr(label) }
    end
  end
end
