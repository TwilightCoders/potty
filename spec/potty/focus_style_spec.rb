# frozen_string_literal: true

RSpec.describe Potty::FocusStyle do
  describe '.none (the default)' do
    subject(:fs) { described_class.none }

    it 'carries no chrome' do
      expect(fs.chrome?).to be(false)
      expect(fs.bordered?).to be(false)
      expect(fs.marker?).to be(false)
      expect(fs.fill).to be(false)
    end

    it 'reserves no marker width' do
      expect(fs.marker_width).to eq(0)
    end
  end

  describe '.boxed' do
    subject(:fs) { described_class.boxed }

    it 'is bordered and counts as chrome' do
      expect(fs.bordered?).to be(true)
      expect(fs.chrome?).to be(true)
    end

    it 'keeps the same border weight on focus by default — only the colour changes' do
      expect(fs.border_for(false)).to eq(:single)
      expect(fs.border_for(true)).to eq(:single) # same weight, not :heavy
      expect(fs.border_color).to eq(:dim)
      expect(fs.focus_color).to eq(:info)
    end

    it 'can opt into a heavier border on focus' do
      f = described_class.boxed(focus: :heavy)
      expect(f.border_for(false)).to eq(:single)
      expect(f.border_for(true)).to eq(:heavy)
    end

    it 'falls back to the base border when no focus_border is given' do
      f = described_class.new(border: :rounded)
      expect(f.border_for(true)).to eq(:rounded)
    end
  end

  describe '.gutter' do
    subject(:fs) { described_class.gutter }

    it 'has a marker but no border' do
      expect(fs.marker?).to be(true)
      expect(fs.bordered?).to be(false)
      expect(fs.chrome?).to be(true)
    end

    it 'reserves the marker width' do
      expect(fs.marker_width).to eq(fs.marker.length)
    end
  end

  describe '.filled' do
    subject(:fs) { described_class.filled }

    it 'fills without border or marker (not counted as box chrome)' do
      expect(fs.fill).to be(true)
      expect(fs.fill_color).to eq(:selected)
      expect(fs.bordered?).to be(false)
      expect(fs.marker?).to be(false)
    end
  end
end
