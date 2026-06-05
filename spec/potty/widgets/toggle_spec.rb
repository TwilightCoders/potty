# frozen_string_literal: true

RSpec.describe Potty::Widgets::Toggle do
  let(:app) { PottySpec.app }
  subject(:toggle) { described_class.new(app, label: 'Wifi') }

  it 'is focusable and defaults off' do
    expect(toggle.can_focus?).to be(true)
    expect(toggle.value).to be(false)
  end

  it 'flips on space' do
    toggle.handle_key(32)
    expect(toggle.value).to be(true)
  end

  it 'flips on enter' do
    toggle.handle_key(10)
    expect(toggle.value).to be(true)
  end

  it 'fires on_change only on real changes' do
    seen = []
    toggle.on_change = ->(v) { seen << v }
    toggle.value = true
    toggle.value = true # no-op, same value
    toggle.value = false
    expect(seen).to eq([true, false])
  end

  it 'coerces truthy assignment to boolean' do
    toggle.value = 'yes'
    expect(toggle.value).to be(true)
  end

  it 'ignores unhandled keys' do
    expect(toggle.handle_key('x'.ord)).to be(false)
  end

  describe '#replace_value (silent write for derived state)' do
    it 'sets the value without emitting :change' do
      seen = []
      toggle.on_change = ->(v) { seen << v }
      toggle.replace_value(true)
      expect(toggle.value).to be(true)
      expect(seen).to eq([])
    end

    it 'coerces truthiness like value=' do
      toggle.replace_value('yes')
      expect(toggle.value).to be(true)
      toggle.replace_value(nil)
      expect(toggle.value).to be(false)
    end
  end
end
