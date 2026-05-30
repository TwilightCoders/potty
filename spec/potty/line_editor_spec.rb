# frozen_string_literal: true

RSpec.describe Potty::LineEditor do
  subject(:editor) { described_class.new('abc') }

  it 'starts with the caret at the end' do
    expect(editor.text).to eq('abc')
    expect(editor.cursor).to eq(3)
  end

  describe 'editing (returns whether text changed)' do
    it 'inserts at the caret' do
      editor.left
      expect(editor.insert('Z')).to be(true)
      expect(editor.text).to eq('abZc')
      expect(editor.cursor).to eq(3)
    end

    it 'backspaces' do
      expect(editor.backspace).to be(true)
      expect(editor.text).to eq('ab')
      expect(editor.backspace).to be(true)
      expect(editor.text).to eq('a')
    end

    it 'returns false on backspace at the start (no change)' do
      editor.home
      expect(editor.backspace).to be(false)
      expect(editor.text).to eq('abc')
    end

    it 'deletes forward' do
      editor.home
      expect(editor.delete_forward).to be(true)
      expect(editor.text).to eq('bc')
    end

    it 'returns false on delete at the end' do
      expect(editor.delete_forward).to be(false)
    end

    it 'honors max_length' do
      e = described_class.new('ab', max_length: 2)
      expect(e.insert('c')).to be(false)
      expect(e.text).to eq('ab')
    end
  end

  describe 'navigation (clamped, no text change)' do
    it 'moves left/right within bounds' do
      editor.home
      editor.left
      expect(editor.cursor).to eq(0)
      editor.to_end
      editor.right
      expect(editor.cursor).to eq(3)
    end
  end

  describe '#text=' do
    it 'replaces the text and clamps the caret' do
      editor.text = 'hi'
      expect(editor.text).to eq('hi')
      expect(editor.cursor).to eq(2)
    end
  end
end
