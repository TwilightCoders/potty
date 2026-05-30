# frozen_string_literal: true

RSpec.describe Potty::Widgets::Button do
  let(:app) { PottySpec.app }

  it 'is focusable' do
    expect(described_class.new(app, label: 'OK').can_focus?).to be(true)
  end

  it 'fires :press on Space and Enter' do
    presses = 0
    b = described_class.new(app, label: 'Go') { } # ensure no error w/o on_press
    b.on(:press) { presses += 1 }
    b.handle_key(Potty::Keys::SPACE)
    b.handle_key(Potty::Keys::ENTER)
    expect(presses).to eq(2)
  end

  it 'supports the on_press: constructor shortcut' do
    pressed = false
    b = described_class.new(app, label: 'Go', on_press: ->(_) { pressed = true })
    b.press
    expect(pressed).to be(true)
  end

  it 'ignores other keys' do
    b = described_class.new(app, label: 'Go')
    expect(b.handle_key('x'.ord)).to be(false)
  end
end
