# frozen_string_literal: true

RSpec.describe Cursed::Widgets::RadioGroup do
  let(:app) { CursedSpec.app }
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
end
