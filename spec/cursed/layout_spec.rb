# frozen_string_literal: true

RSpec.describe Cursed::Layout do
  # Minimal widget stub answering the layout protocol.
  let(:widget_class) do
    Struct.new(:h) do
      def preferred_height(_width) = h
    end
  end

  describe '.stack' do
    it 'stacks widgets vertically with spacing' do
      container = Cursed::Layout::Rect.new(0, 0, 20, 100)
      widgets = [widget_class.new(2), widget_class.new(3)]
      rects = described_class.stack(container, widgets, spacing: 1)

      expect(rects.map(&:y)).to eq([0, 3]) # 0, then 0+2+1
      expect(rects.map(&:height)).to eq([2, 3])
      expect(rects.map(&:width)).to all(eq(20))
    end
  end

  describe '.split_horizontal' do
    it 'splits a rect by ratio' do
      container = Cursed::Layout::Rect.new(0, 0, 100, 10)
      left, right = described_class.split_horizontal(container, ratio: 0.3)

      expect(left.width).to eq(30)
      expect(right.x).to eq(30)
      expect(right.width).to eq(70)
    end
  end

  describe '.fill' do
    it 'returns a copy of the container' do
      container = Cursed::Layout::Rect.new(1, 2, 3, 4)
      filled = described_class.fill(container)
      expect(filled).to eq(container)
      expect(filled).not_to equal(container)
    end
  end
end
