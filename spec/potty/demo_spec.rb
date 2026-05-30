# frozen_string_literal: true

# Regression guard for the shipped bin/potty_demo: the self-demonstrating
# dashboard must build/lay out/render/tick against a fake terminal, and its
# meta wiring (controls reconfiguring the demo) must hold.

load File.expand_path('../../bin/potty_demo', __dir__) unless defined?(PottyDemo)

RSpec.describe 'bin/potty_demo' do
  # A fake Surface: answers size and no-ops the draw calls (attron yields).
  let(:surface) do
    Object.new.tap do |s|
      def s.size = [24, 80]
      def s.erase = nil
      def s.setpos(*) = nil
      def s.addstr(*) = nil
      def s.attron(*) = (yield if block_given?)
      def s.present = nil
    end
  end

  let(:app) do
    surf = surface
    Object.new.tap do |a|
      theme = Object.new
      def theme.style(_n, **_o) = Potty::Style.new(fg: :default, bg: :default)
      def theme.[](_k) = 0
      def theme.attr(_k, **_o) = 0
      a.define_singleton_method(:theme) { theme }
      a.define_singleton_method(:surface) { surf }
      a.define_singleton_method(:quit) {}
    end
  end

  subject(:dash) { PottyDemo::Dashboard.new(app).tap { |v| v.activate(app) } }

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

    it 'advances focus when Enter is pressed in the Title field' do
      expect(ivar(:@title_in).focused).to be(true)
      dash.handle_key(Potty::Keys::ENTER)
      expect(ivar(:@title_in).focused).to be(false)
      expect(ivar(:@style_rg).focused).to be(true) # next focusable
    end

    it 'restyles BOTH panels when you Tab to the Border radio and pick one' do
      dash.handle_key(Potty::Keys::TAB)   # title -> radio
      dash.handle_key(Potty::Keys::DOWN)  # -> :rounded
      dash.handle_key(Potty::Keys::SPACE) # commit
      expect(ivar(:@controls_panel).style).to eq(:rounded)
      expect(ivar(:@live_panel).style).to eq(:rounded)
    end

    it 'stops the animation when you Tab to the Toggle and press Space' do
      anim = ivar(:@anim)
      dash.handle_key(Potty::Keys::TAB) # title -> radio
      dash.handle_key(Potty::Keys::TAB) # radio -> toggle
      dash.handle_key(Potty::Keys::SPACE)
      expect(ivar(:@animate).value).to be(false)
      expect(anim.playing?).to be(false)
    end

    it 'hides a live widget via the checkbox group' do
      show = ivar(:@show)
      # reach the checkbox group: title -> radio -> toggle -> checkboxes
      3.times { dash.handle_key(Potty::Keys::TAB) }
      expect(show.focused).to be(true)
      dash.handle_key(Potty::Keys::SPACE) # toggle :anim off
      expect(ivar(:@anim).visible?).to be(false)
    end

    it 'replays the plane when Salute is reached and pressed' do
      ivar(:@anim).play(:spinner)
      4.times { dash.handle_key(Potty::Keys::TAB) } # -> Salute button
      expect(ivar(:@salute).focused).to be(true)
      dash.handle_key(Potty::Keys::ENTER)
      expect(ivar(:@anim).current).to eq(:plane)
    end
  end
end
