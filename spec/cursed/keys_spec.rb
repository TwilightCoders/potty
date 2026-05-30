# frozen_string_literal: true

RSpec.describe Cursed::Keys do
  it 'exposes ASCII control codes' do
    expect(described_class::ENTER).to eq(10)
    expect(described_class::ESC).to eq(27)
    expect(described_class::TAB).to eq(9)
    expect(described_class::SPACE).to eq(32)
  end

  it 'resolves special keys to integers' do
    %i[UP DOWN LEFT RIGHT HOME END_ DELETE BACKSPACE SHIFT_TAB RESIZE].each do |k|
      expect(described_class.const_get(k)).to be_a(Integer)
    end
  end

  describe '.enter?' do
    it 'matches both Enter and Return' do
      expect(described_class.enter?(10)).to be(true)
      expect(described_class.enter?(13)).to be(true)
      expect(described_class.enter?(32)).to be(false)
    end
  end

  describe '.backspace?' do
    it 'matches DEL, Ctrl+H, and the curses backspace key' do
      expect(described_class.backspace?(127)).to be(true)
      expect(described_class.backspace?(8)).to be(true)
      expect(described_class.backspace?(described_class::BACKSPACE)).to be(true)
    end
  end

  describe '.printable?' do
    it 'accepts the printable ASCII range only' do
      expect(described_class.printable?(32)).to be(true)
      expect(described_class.printable?(126)).to be(true)
      expect(described_class.printable?(127)).to be(false)
      expect(described_class.printable?(27)).to be(false)
      expect(described_class.printable?(nil)).to be(false)
    end
  end
end
