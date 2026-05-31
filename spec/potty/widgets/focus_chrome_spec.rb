# frozen_string_literal: true

# Focus chrome (potty's `:focus` stylesheet) plumbed through Base and exercised
# via real focusable widgets. A fake window records draw ops; a real Theme
# carries the FocusStyle.
RSpec.describe 'Focus chrome' do
  # Fake window recording setpos/addstr and the attron style (so we can assert
  # the border *colour* without a real surface). The first attron in a render
  # is the border's (Border.draw wraps the whole box in one attron block).
  def window
    Object.new.tap do |w|
      w.instance_variable_set(:@ops, [])
      def w.ops = @ops
      def w.setpos(y, x) = @ops << [:setpos, y, x]
      def w.addstr(s) = @ops << [:addstr, s]
      def w.attron(a) = (@ops << [:attron, a]; yield if block_given?)
      def w.addstrs = @ops.select { |o| o[0] == :addstr }.map { |o| o[1] }
      def w.first_attron = @ops.find { |o| o[0] == :attron }&.at(1)
    end
  end

  def app_with(theme)
    Object.new.tap { |a| a.define_singleton_method(:theme) { theme } }
  end

  let(:rect) { Potty::Layout::Rect.new(0, 0, 20, 1) }

  describe 'an explicit FocusStyle.none theme (the bare look)' do
    let(:app) { app_with(Potty::Theme.new(nil, Potty::FocusStyle.none)) }
    subject(:button) { Potty::Widgets::Button.new(app, label: 'Go') }

    it 'reserves no chrome height' do
      expect(button.preferred_height(20)).to eq(1)
    end

    it 'content_rect equals the outer rect' do
      button.layout(rect)
      expect(button.content_rect).to eq(rect)
    end

    it 'draws no border or marker' do
      button.layout(rect)
      button.focus
      win = window
      button.render(win)
      expect(win.addstrs).to eq(['[ Go ]']) # just the label, no chrome
    end
  end

  describe 'the default theme (now FocusStyle.gutter)' do
    let(:app) { app_with(Potty::Theme.new) }
    subject(:button) { Potty::Widgets::Button.new(app, label: 'Go') }

    it 'adds no height (gutter lives in a reserved column)' do
      expect(button.preferred_height(20)).to eq(1)
    end

    it 'insets content by the marker width but draws the marker only on focus' do
      button.layout(rect)
      expect(button.content_rect.x).to eq(Potty::FocusStyle.gutter.marker_width)

      win = window
      button.render(win)
      expect(win.addstrs).to eq(['[ Go ]']) # unfocused: no marker

      button.focus
      win2 = window
      button.render(win2)
      expect(win2.addstrs).to include(Potty::FocusStyle.gutter.marker)
    end
  end

  describe 'a boxed theme (border lights on focus)' do
    let(:theme) { Potty::Theme.new(nil, Potty::FocusStyle.boxed) }
    let(:app) { app_with(theme) }
    subject(:button) { Potty::Widgets::Button.new(app, label: 'Go') }

    it 'reserves two rows for the border' do
      expect(button.preferred_height(20)).to eq(3)
    end

    it 'insets the content rect by the border' do
      button.layout(Potty::Layout::Rect.new(2, 1, 20, 3))
      cr = button.content_rect
      expect([cr.x, cr.y, cr.width, cr.height]).to eq([3, 2, 18, 1])
    end

    it 'draws a single (dim) border when unfocused' do
      button.layout(Potty::Layout::Rect.new(0, 0, 8, 3))
      win = window
      button.render(win)
      expect(win.addstrs.first).to start_with("┌")          # single corner
      expect(win.first_attron.fg).to eq(theme.style(:dim).fg) # dim colour
    end

    it 'keeps the same border weight on focus and only recolors it' do
      button.layout(Potty::Layout::Rect.new(0, 0, 8, 3))
      button.focus
      win = window
      button.render(win)
      expect(win.addstrs.first).to start_with("┌")           # still single — no thickening
      expect(win.addstrs.first).not_to start_with("┏")        # not heavy
      expect(win.first_attron.fg).to eq(theme.style(:info).fg) # focus colour
    end

    it 'still supports an opt-in heavier focus border' do
      heavy_app = app_with(Potty::Theme.new(nil, Potty::FocusStyle.boxed(focus: :heavy)))
      btn = Potty::Widgets::Button.new(heavy_app, label: 'Go')
      btn.layout(Potty::Layout::Rect.new(0, 0, 8, 3))
      btn.focus
      win = window
      btn.render(win)
      expect(win.addstrs.first).to start_with("┏") # heavy corner
    end
  end

  describe 'a gutter theme (marker on focus, no reflow)' do
    let(:theme) { Potty::Theme.new(nil, Potty::FocusStyle.gutter) }
    let(:app) { app_with(theme) }
    subject(:input) { Potty::Widgets::TextInput.new(app, text: 'x') }

    it 'adds no height (marker lives in a reserved gutter column)' do
      expect(input.preferred_height(20)).to eq(1)
    end

    it 'insets content by the marker width but not vertically' do
      input.layout(rect)
      cr = input.content_rect
      expect([cr.x, cr.y, cr.height]).to eq([theme.focus_style.marker_width, 0, 1])
    end

    it 'draws the marker only when focused' do
      input.layout(rect)
      win = window
      input.render(win)
      expect(win.addstrs).not_to include(theme.focus_style.marker)

      input.focus
      win2 = window
      input.render(win2)
      expect(win2.addstrs).to include(theme.focus_style.marker)
    end
  end

  describe 'chrome is scoped to focusable widgets' do
    let(:theme) { Potty::Theme.new(nil, Potty::FocusStyle.boxed) }
    let(:app) { app_with(theme) }

    it 'does not box a non-focusable Label even under a boxed theme' do
      label = Potty::Widgets::Label.new(app, text: 'hi')
      expect(label.preferred_height(20)).to eq(1) # no +2
      label.layout(rect)
      expect(label.content_rect).to eq(rect) # no inset
    end
  end

  describe 'per-widget override beats the theme' do
    let(:theme) { Potty::Theme.new(nil, Potty::FocusStyle.boxed) }
    let(:app) { app_with(theme) }

    it 'lets a single field opt out of the global box' do
      input = Potty::Widgets::TextInput.new(app)
      input.focus_style = Potty::FocusStyle.none
      expect(input.preferred_height(20)).to eq(1)
    end
  end

  describe 'TextInput fill' do
    let(:theme) { Potty::Theme.new(nil, Potty::FocusStyle.filled) }
    let(:app) { app_with(theme) }

    it 'paints the full field width when focused (empty field still lit)' do
      input = Potty::Widgets::TextInput.new(app)
      input.layout(rect)
      input.focus
      win = window
      input.render(win)
      # The focused empty field renders width-padded blanks (the fill), not an
      # early-return placeholder.
      expect(win.addstrs.any? { |s| s.length == rect.width }).to be(true)
    end
  end
end
