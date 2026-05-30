# frozen_string_literal: true

RSpec.describe Potty::Widgets::Container do
  let(:app) { PottySpec.app }
  let(:rect) { Potty::Layout::Rect }

  # A focusable leaf with a settable preferred height.
  let(:leaf_class) do
    Class.new(Potty::Widgets::Base) do
      def initialize(app, h: 1, focusable: false)
        super(app)
        @h = h
        @focusable = focusable
      end

      def can_focus? = @focusable
      def preferred_height(_w) = @h
    end
  end

  def leaf(h: 1, focusable: false)
    leaf_class.new(app, h: h, focusable: focusable)
  end

  describe Potty::Widgets::VBox do
    subject(:vbox) { described_class.new(app, spacing: 1) }

    it 'sums child heights plus spacing' do
      vbox.add(leaf(h: 2), leaf(h: 3))
      expect(vbox.preferred_height(80)).to eq(6) # 2 + 1 + 3
    end

    it 'lays children out top to bottom' do
      a = leaf(h: 2)
      b = leaf(h: 3)
      vbox.add(a, b)
      vbox.layout(rect.new(0, 0, 20, 10))
      expect(a.rect.y).to eq(0)
      expect(b.rect.y).to eq(3) # after a (2) + spacing (1)
      expect([a, b].map { |w| w.rect.width }).to all(eq(20))
    end
  end

  describe Potty::Widgets::HBox do
    subject(:hbox) { described_class.new(app) }

    it 'splits width into equal columns, last absorbs remainder' do
      a = leaf
      b = leaf
      c = leaf
      hbox.add(a, b, c)
      hbox.layout(rect.new(0, 0, 10, 4))
      expect(a.rect.width).to eq(3)
      expect(b.rect.width).to eq(3)
      expect(c.rect.width).to eq(4) # 10 - 3 - 3
      expect(a.rect.x).to eq(0)
      expect(b.rect.x).to eq(3)
      expect(c.rect.x).to eq(6)
    end

    it 'gives each child the full height' do
      a = leaf
      hbox.add(a)
      hbox.layout(rect.new(0, 0, 10, 5))
      expect(a.rect.height).to eq(5)
    end
  end

  describe 'focus traversal' do
    it 'collects focusable leaves depth-first across nesting' do
      f1 = leaf(focusable: true)
      f2 = leaf(focusable: true)
      plain = leaf(focusable: false)
      inner = described_class.new(app).add(f2, plain)
      outer = Potty::Widgets::VBox.new(app).add(f1, inner)
      expect(outer.focusable_widgets).to eq([f1, f2])
    end
  end

  describe 'recursion' do
    it 'propagates tick to children' do
      ticked = []
      leaf_a = leaf
      leaf_a.define_singleton_method(:tick) { |now| ticked << now }
      Potty::Widgets::VBox.new(app).add(leaf_a).tick(:t)
      expect(ticked).to eq([:t])
    end

    it 'add returns self and sets parent' do
      child = leaf
      box = described_class.new(app)
      expect(box.add(child)).to equal(box)
      expect(child.parent).to equal(box)
    end
  end
end
