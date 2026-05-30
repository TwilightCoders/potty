# frozen_string_literal: true

RSpec.describe Potty::Keys do
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

  describe '.code' do
    it 'turns a printable String from getch into its integer code' do
      expect(described_class.code('h')).to eq(104)
      expect(described_class.code(' ')).to eq(32)
    end

    it 'maps control Strings to their code (Enter, Tab, ESC)' do
      expect(described_class.code("\n")).to eq(10)
      expect(described_class.code("\t")).to eq(9)
      expect(described_class.code("\e")).to eq(27)
    end

    it 'passes Integers and nil through unchanged' do
      expect(described_class.code(259)).to eq(259)
      expect(described_class.code(nil)).to be_nil
    end

    it 'treats an empty String as no input' do
      expect(described_class.code('')).to be_nil
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
