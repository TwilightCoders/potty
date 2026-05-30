# frozen_string_literal: true

RSpec.describe Potty::Widgets::List do
  let(:app) { PottySpec.app }
  subject(:list) { described_class.new(app) }

  def sep(text = '')
    Potty::Widgets::SeparatorItem.new(text)
  end

  def action(text, &blk)
    Potty::Widgets::ActionItem.new(text, &blk)
  end

  describe 'initial selection' do
    it 'lands on the first selectable item, skipping a leading separator' do
      first = action('one')
      list.items = [sep('TITLE'), first, action('two')]
      expect(list.selected_item).to eq(first)
    end

    it 'falls back to index 0 when nothing is selectable' do
      only = sep('TITLE')
      list.items = [only]
      expect(list.selected_item).to eq(only)
    end

    it 'is nil for an empty list' do
      list.items = []
      expect(list.selected_item).to be_nil
    end
  end

  describe 'navigation' do
    it 'skips disabled items and emits :select' do
      a = action('a')
      b = action('b')
      list.items = [a, sep, b]
      seen = []
      list.on(:select) { |it| seen << it }
      list.handle_key(Potty::Keys::DOWN) # a -> (skip sep) -> b
      expect(list.selected_item).to eq(b)
      expect(seen.last).to eq(b)
    end

    it 'activates the selected item and emits :activate' do
      fired = nil
      a = action('a')
      b = action('b') { fired = :b }
      list.items = [a, b]
      activated = nil
      list.on(:activate) { |it| activated = it }
      list.handle_key(Potty::Keys::DOWN)  # -> b
      list.handle_key(Potty::Keys::ENTER) # activate
      expect(activated).to eq(b)
      expect(fired).to eq(:b)
    end
  end
end
