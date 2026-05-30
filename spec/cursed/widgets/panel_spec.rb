# frozen_string_literal: true

RSpec.describe Cursed::Widgets::Panel do
  let(:app) { CursedSpec.app }
  let(:rect) { Cursed::Layout::Rect }

  let(:leaf_class) do
    Class.new(Cursed::Widgets::Base) do
      def initialize(app, h: 1)
        super(app)
        @h = h
      end

      def preferred_height(_w) = @h
    end
  end

  subject(:panel) { described_class.new(app, title: 'Box') }

  it 'adds 2 rows of border to child height' do
    panel.add(leaf_class.new(app, h: 3))
    expect(panel.preferred_height(20)).to eq(5) # 3 + top + bottom
  end

  it 'lays children inside the border frame (inset by 1)' do
    child = leaf_class.new(app, h: 2)
    panel.add(child)
    panel.layout(rect.new(0, 0, 20, 10))
    expect(child.rect.x).to eq(1)
    expect(child.rect.y).to eq(1)
    expect(child.rect.width).to eq(18) # 20 - 2
  end

  it 'is itself non-focusable' do
    expect(panel.can_focus?).to be(false)
  end
end
