# frozen_string_literal: true

# Regression guard for the shipped bin/cursed_demo: the self-demonstrating
# dashboard must build/lay out/render/tick against a fake terminal, and its
# meta wiring (controls reconfiguring the demo) must hold.

load File.expand_path('../../bin/cursed_demo', __dir__) unless defined?(CursedDemo)

RSpec.describe 'bin/cursed_demo' do
  let(:window) do
    Object.new.tap do |w|
      def w.setpos(*) = nil
      def w.addstr(*) = nil
      def w.attron(*) = (yield if block_given?)
      def w.erase = nil
    end
  end

  let(:wm) do
    win = window
    Object.new.tap do |m|
      m.define_singleton_method(:max_y) { 24 }
      m.define_singleton_method(:max_x) { 80 }
      m.define_singleton_method(:stdscr) { win }
      m.define_singleton_method(:refresh_all) {}
    end
  end

  let(:app) do
    manager = wm
    Object.new.tap do |a|
      theme = Object.new
      def theme.[](_k) = 0
      def theme.attr(_k, **_o) = 0
      a.define_singleton_method(:theme) { theme }
      a.define_singleton_method(:window_manager) { manager }
      a.define_singleton_method(:quit) {}
    end
  end

  subject(:dash) { CursedDemo::Dashboard.new(app).tap { |v| v.activate(app) } }

  def ivar(name)
    dash.instance_variable_get(name)
  end

  it 'builds, lays out, renders, and ticks without error' do
    expect { dash.render }.not_to raise_error
    expect { dash.tick(Time.at(100)) }.not_to raise_error
  end

  it 'opens with the title field focused (not a separator/panel)' do
    expect(ivar(:@title_in).focused).to be(true)
  end

  # These drive input through dash.handle_key — the exact path the
  # Application event loop uses — so they exercise focus delegation into
  # the nested Panel/HBox tree, not just the widgets in isolation.
  describe 'meta wiring (via View#handle_key)' do
    it 'retitles the header live as you type into the focused field' do
      'meta'.each_char { |c| dash.handle_key(c.ord) }
      expect(ivar(:@header).text).to include('meta')
    end

    it 'restyles BOTH panels when you Tab to the Border radio and pick one' do
      dash.handle_key(Cursed::Keys::TAB)   # title -> radio
      dash.handle_key(Cursed::Keys::DOWN)  # -> :rounded
      dash.handle_key(Cursed::Keys::SPACE) # commit
      expect(ivar(:@controls_panel).style).to eq(:rounded)
      expect(ivar(:@live_panel).style).to eq(:rounded)
    end

    it 'stops the animation when you Tab to the Toggle and press Space' do
      anim = ivar(:@anim)
      dash.handle_key(Cursed::Keys::TAB) # title -> radio
      dash.handle_key(Cursed::Keys::TAB) # radio -> toggle
      dash.handle_key(Cursed::Keys::SPACE)
      expect(ivar(:@animate).value).to be(false)
      expect(anim.playing?).to be(false)
    end

    it 'hides a live widget via the checkbox group' do
      show = ivar(:@show)
      # reach the checkbox group: title -> radio -> toggle -> checkboxes
      3.times { dash.handle_key(Cursed::Keys::TAB) }
      expect(show.focused).to be(true)
      dash.handle_key(Cursed::Keys::SPACE) # toggle :anim off
      expect(ivar(:@anim).visible?).to be(false)
    end

    it 'replays the plane when Salute is reached and pressed' do
      ivar(:@anim).play(:spinner)
      4.times { dash.handle_key(Cursed::Keys::TAB) } # -> Salute button
      expect(ivar(:@salute).focused).to be(true)
      dash.handle_key(Cursed::Keys::ENTER)
      expect(ivar(:@anim).current).to eq(:plane)
    end
  end
end
