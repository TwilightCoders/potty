# frozen_string_literal: true

require_relative 'base'
require_relative 'list_item'
require_relative '../keys'

module Cursed
  module Widgets
    # Scrollable list widget with heterogeneous items.
    # Emits :select(item) on cursor move and :activate(item) on Enter.
    class List < Base
      attr_accessor :items, :on_select, :on_activate

      def initialize(app)
        super
        @items = []
        @selected_index = 0
        @scroll_offset = 0
        @on_select = nil
        @on_activate = nil
      end

      def can_focus?
        true
      end

      def preferred_height(width)
        [@items.size + 2, 10].max  # Items + borders, minimum 10
      end

      def render(window)
        return unless @rect

        visible_height = @rect.height - 2  # Account for borders

        # Draw border
        draw_border(window)

        # Show empty message if no items
        if @items.empty?
          window.setpos(@rect.y + 1, @rect.x + 2)
          window.attron(theme[:dim]) do
            window.addstr("No items")
          end
          return
        end

        # Draw visible items
        visible_items = @items[@scroll_offset, visible_height] || []
        visible_items.each_with_index do |item, display_idx|
          real_idx = @scroll_offset + display_idx
          y = @rect.y + 1 + display_idx
          x = @rect.x + 1

          render_item(window, item, real_idx, y, x)
        end
      end

      def handle_key(ch)
        return false if @items.empty?

        case ch
        when Keys::UP
          move_selection(-1)
          true
        when Keys::DOWN
          move_selection(1)
          true
        when *Keys::ENTERS
          activate_current
          true
        else
          # Delegate to current item (e.g., InputItem handles typing)
          current_item&.handle_key(ch)
        end
      end

      private

      def draw_border(window)
        # Top border
        window.setpos(@rect.y, @rect.x)
        window.addstr("\u250C" + ("\u2500" * (@rect.width - 2)) + "\u2510")

        # Side borders
        (@rect.height - 2).times do |i|
          window.setpos(@rect.y + 1 + i, @rect.x)
          window.addstr("\u2502")
          window.setpos(@rect.y + 1 + i, @rect.x + @rect.width - 1)
          window.addstr("\u2502")
        end

        # Bottom border
        window.setpos(@rect.y + @rect.height - 1, @rect.x)
        window.addstr("\u2514" + ("\u2500" * (@rect.width - 2)) + "\u2518")
      end

      def render_item(window, item, index, y, x)
        is_selected = (index == @selected_index)
        is_disabled = item.disabled?
        max_width = @rect.width - 3

        window.setpos(y, x)

        # Selection prefix
        prefix_attr = is_selected && @focused ? theme.attr(:selected, bold: true) : theme[:normal]
        window.attron(prefix_attr) do
          prefix = is_selected ? "\u2192 " : "  "
          window.addstr(prefix)
        end

        # Try custom rendering first
        if item.render_custom(window, theme, max_width - 2)
          return  # Item handled its own rendering
        end

        # Default single-color rendering
        attr = if is_selected && @focused
                 theme.attr(:selected, bold: true)
               elsif is_disabled
                 theme[:dim]
               elsif item.color
                 theme[item.color]
               else
                 theme[:normal]
               end

        window.attron(attr) do
          text = item.display_text
          window.addstr(text[0, max_width - 2])
        end
      end

      def move_selection(delta)
        return if @items.empty?

        # Find next enabled item
        attempts = 0
        new_index = @selected_index

        loop do
          new_index = (new_index + delta) % @items.size
          break if !@items[new_index].disabled? || attempts >= @items.size
          attempts += 1
        end

        @selected_index = new_index
        adjust_scroll
        @on_select&.call(@items[@selected_index])
        emit(:select, @items[@selected_index])
      end

      def adjust_scroll
        visible_height = @rect.height - 2

        # Scroll down if needed
        if @selected_index >= @scroll_offset + visible_height
          @scroll_offset = @selected_index - visible_height + 1
        end

        # Scroll up if needed
        if @selected_index < @scroll_offset
          @scroll_offset = @selected_index
        end
      end

      def activate_current
        return if @items.empty?

        item = @items[@selected_index]
        return if item.disabled?

        @on_activate&.call(item)
        emit(:activate, item)
        item.activate
      end

      def current_item
        @items[@selected_index] if @selected_index < @items.size
      end
    end
  end
end
