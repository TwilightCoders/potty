# frozen_string_literal: true

RSpec.describe Cursed::Theme do
  describe 'transparent defaults' do
    it 'uses the terminal default fg/bg for normal text' do
      expect(described_class::PAIRS[:normal]).to eq([described_class::DEFAULT, described_class::DEFAULT])
      expect(described_class::DEFAULT).to eq(-1)
    end

    it 'gives the semantic text colors a transparent background' do
      %i[success error warning info dim].each do |name|
        _fg, bg = described_class::PAIRS[name]
        expect(bg).to eq(described_class::DEFAULT), "#{name} should have a transparent bg"
      end
    end

    it 'keeps explicit backgrounds only on deliberate highlights' do
      expect(described_class::PAIRS[:selected].last).to eq(::Curses::COLOR_GREEN)
      expect(described_class::PAIRS[:header].last).to eq(::Curses::COLOR_BLUE)
      expect(described_class::PAIRS[:status].last).to eq(::Curses::COLOR_CYAN)
    end
  end
end
