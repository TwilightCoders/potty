# frozen_string_literal: true

RSpec.describe Potty::Widgets::CheckboxGroup do
  let(:app) { PottySpec.app }
  let(:options) { [{ value: :a, label: 'A' }, { value: :b, label: 'B' }, { value: :c, label: 'C' }] }
  subject(:group) { described_class.new(app, options: options) }

  it 'starts with nothing selected and is focusable' do
    expect(group.selected).to eq([])
    expect(group.can_focus?).to be(true)
  end

  it 'honors an initial selection' do
    g = described_class.new(app, options: options, selected: [:b])
    expect(g.selected).to eq([:b])
    expect(g.selected?(:b)).to be(true)
  end

  it 'toggles the option under the cursor on space' do
    group.handle_key(Potty::Keys::SPACE)        # toggle :a on
    group.handle_key(Potty::Keys::DOWN)
    group.handle_key(Potty::Keys::DOWN)
    group.handle_key(Potty::Keys::SPACE)        # toggle :c on
    expect(group.selected).to eq(%i[a c])
  end

  it 'toggles off when pressed again' do
    group.handle_key(Potty::Keys::SPACE)        # :a on
    group.handle_key(Potty::Keys::SPACE)        # :a off
    expect(group.selected).to eq([])
  end

  it 'wraps cursor movement' do
    group.handle_key(Potty::Keys::UP)           # 0 -> last
    group.handle_key(Potty::Keys::SPACE)
    expect(group.selected).to eq([:c])
  end

  it 'emits :change with a snapshot on toggle' do
    seen = []
    group.on(:change) { |sel| seen << sel }
    group.handle_key(Potty::Keys::SPACE)
    group.handle_key(Potty::Keys::DOWN)
    group.handle_key(Potty::Keys::SPACE)
    expect(seen).to eq([[:a], %i[a b]])
  end

  it 'normalizes bare-value options' do
    g = described_class.new(app, options: %i[x y])
    expect(g.options).to eq([{ value: :x, label: 'x' }, { value: :y, label: 'y' }])
  end

  it 'reports preferred_height as option count' do
    expect(group.preferred_height(80)).to eq(3)
  end
end
