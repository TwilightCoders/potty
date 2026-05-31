# frozen_string_literal: true

RSpec.describe Potty::Widgets::RadioGroup do
  let(:app) { PottySpec.app }
  let(:options) do
    [{ value: :red, label: 'Red' },
     { value: :green, label: 'Green' },
     { value: :blue, label: 'Blue' }]
  end
  subject(:group) { described_class.new(app, options: options) }

  it 'defaults selection to the first option' do
    expect(group.selected).to eq(:red)
  end

  it 'normalizes bare values into value/label hashes' do
    g = described_class.new(app, options: %i[a b])
    expect(g.options).to eq([{ value: :a, label: 'a' }, { value: :b, label: 'b' }])
  end

  it 'moves the cursor without committing selection' do
    group.handle_key(Curses::Key::DOWN)
    expect(group.selected).to eq(:red) # cursor moved, selection unchanged
  end

  it 'commits the cursor option on space' do
    group.handle_key(Curses::Key::DOWN)
    group.handle_key(32)
    expect(group.selected).to eq(:green)
  end

  it 'commits on enter' do
    group.handle_key(Curses::Key::DOWN)
    group.handle_key(Curses::Key::DOWN)
    group.handle_key(10)
    expect(group.selected).to eq(:blue)
  end

  it 'wraps cursor movement' do
    group.handle_key(Curses::Key::UP) # from index 0 -> last
    group.handle_key(32)
    expect(group.selected).to eq(:blue)
  end

  it 'fires on_change only on real selection changes' do
    seen = []
    group.on_change = ->(v) { seen << v }
    group.handle_key(32) # re-select :red (cursor still at 0) -> no change
    group.handle_key(Curses::Key::DOWN)
    group.handle_key(32) # -> :green
    expect(seen).to eq([:green])
  end

  it 'assigns selected= by value and fires on_change' do
    seen = []
    group.on_change = ->(v) { seen << v }
    group.selected = :blue
    expect(group.selected).to eq(:blue)
    expect(seen).to eq([:blue])
  end

  it 'ignores selected= for unknown values' do
    group.selected = :purple
    expect(group.selected).to eq(:red)
  end

  it 'reports preferred_height as option count' do
    expect(group.preferred_height(80)).to eq(3)
  end

  # Regression: a shorter row replacing a longer one left the previous
  # row's tail on screen ("(○) all interfaces (0.0.0.0)" → cursor moves →
  # "(●) en0 (192.168.1.42)" without ljust → tail of ").0)" hangs at the
  # right). #draw now pads each row to rect.width so any prior content
  # gets overwritten with spaces. See claudepilot #82 (the visual artifact
  # Dale caught in the Ctrl-] panel bind-interface picker).
  describe '#draw pads each row to rect.width' do
    let(:draw_app) do
      theme = Object.new
      theme.define_singleton_method(:selection_style) { |_| 0 }
      app = Object.new
      app.define_singleton_method(:theme) { theme }
      app
    end

    let(:window) do
      writes = []
      win = Object.new
      win.define_singleton_method(:writes) { writes }
      win.define_singleton_method(:setpos) { |_y, _x| nil }
      win.define_singleton_method(:addstr) { |s| writes << s }
      win.define_singleton_method(:attron) { |_a, &blk| blk&.call }
      win
    end

    let(:rect) { Potty::Layout::Rect.new(0, 0, 20, 3) } # cols=20

    it 'each row is exactly rect.width characters (ljust-padded)' do
      g = described_class.new(draw_app, options: options)
      g.layout(rect)
      g.draw(window)
      expect(window.writes.size).to eq(3)
      window.writes.each { |row| expect(row.length).to eq(20) }
    end

    it 'truncates a too-long row to rect.width (no overflow)' do
      huge_options = [{ value: :x, label: 'A' * 100 }]
      g = described_class.new(draw_app, options: huge_options)
      g.layout(rect)
      g.draw(window)
      expect(window.writes.first.length).to eq(20)
    end
  end
end
