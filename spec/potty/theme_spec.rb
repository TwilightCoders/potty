# frozen_string_literal: true

RSpec.describe Potty::Theme do
  describe 'semantic palette' do
    it 'uses the terminal default fg/bg for normal text (transparent)' do
      expect(described_class::PALETTE[:normal]).to eq(fg: :default, bg: :default)
    end

    it 'gives the semantic text colors a transparent (default) background' do
      %i[success error warning info dim].each do |name|
        expect(described_class::PALETTE[name][:bg]).to eq(:default), "#{name} should have a transparent bg"
      end
    end

    it 'keeps explicit backgrounds only on deliberate highlights' do
      expect(described_class::PALETTE[:selected][:bg]).to eq(:green)
      expect(described_class::PALETTE[:header][:bg]).to eq(:blue)
      expect(described_class::PALETTE[:status][:bg]).to eq(:cyan)
    end

    it 'maps :default to the curses -1 (terminal default)' do
      expect(described_class::COLORS[:default]).to eq(-1)
    end
  end

  describe '#style' do
    # No curses init needed — style() is pure semantic resolution.
    subject(:theme) { described_class.allocate.tap { |t| t.instance_variable_set(:@palette, described_class::PALETTE) } }

    it 'returns a Style with the palette colors' do
      s = theme.style(:info)
      expect(s).to be_a(Potty::Style)
      expect(s.fg).to eq(:cyan)
      expect(s.bg).to eq(:default)
      expect(s.bold?).to be(false)
    end

    it 'carries the requested attributes' do
      s = theme.style(:selected, bold: true, reverse: true)
      expect(s.bold?).to be(true)
      expect(s.reverse?).to be(true)
      expect(s.underline?).to be(false)
    end

    it 'falls back to :normal for an unknown name' do
      expect(theme.style(:nope).fg).to eq(theme.style(:normal).fg)
    end
  end

  describe 'custom palette' do
    it 'merges overrides over the defaults' do
      theme = described_class.allocate
      theme.instance_variable_set(:@palette, described_class::PALETTE.merge(info: { fg: :magenta, bg: :default }))
      expect(theme.style(:info).fg).to eq(:magenta)
    end
  end
end
