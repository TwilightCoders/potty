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

  # Theme is pure data now (no curses), so it instantiates plainly.
  subject(:theme) { described_class.new }

  describe '#style' do
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

  describe 'the [] and attr aliases (the one-place fix)' do
    it '[] returns the same Style as #style — so every widget renders in any mode' do
      expect(theme[:info]).to eq(theme.style(:info))
      expect(theme[:info]).to be_a(Potty::Style)
    end

    it 'attr returns a Style carrying bold/underline' do
      s = theme.attr(:selected, bold: true)
      expect(s).to be_a(Potty::Style)
      expect(s.bold?).to be(true)
    end
  end

  describe 'custom palette' do
    it 'merges overrides over the defaults' do
      custom = described_class.new(info: { fg: :magenta, bg: :default })
      expect(custom.style(:info).fg).to eq(:magenta)
    end
  end
end
