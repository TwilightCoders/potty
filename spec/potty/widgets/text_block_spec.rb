# frozen_string_literal: true

RSpec.describe Potty::Widgets::TextBlock do
  let(:theme) { Object.new.tap { |t| def t.style(_k, **_o) = 0 } }
  let(:app) do
    th = theme
    Object.new.tap { |a| a.define_singleton_method(:theme) { th } }
  end

  # Fake window recording addstr strings and setpos rows.
  let(:window) do
    Object.new.tap do |w|
      w.instance_variable_set(:@ops, [])
      def w.ops = @ops
      def w.setpos(y, x) = @ops << [:setpos, y, x]
      def w.addstr(s) = @ops << [:addstr, s]
      def w.attron(_a) = (yield if block_given?)
      def w.strs = @ops.select { |o| o[0] == :addstr }.map { |o| o[1] }
    end
  end

  it 'is not focusable' do
    expect(described_class.new(app).can_focus?).to be(false)
  end

  describe 'verbatim (wrap: false)' do
    subject(:block) { described_class.new(app, text: "line one\nline two\nline three") }

    it 'reports height as the line count' do
      expect(block.preferred_height(80)).to eq(3)
    end

    it 'renders each source line on its own row at the rect origin' do
      block.layout(Potty::Layout::Rect.new(2, 5, 40, 3))
      block.render(window)
      expect(window.ops).to include([:setpos, 5, 2], [:addstr, 'line one'])
      expect(window.ops).to include([:setpos, 6, 2], [:addstr, 'line two'])
      expect(window.ops).to include([:setpos, 7, 2], [:addstr, 'line three'])
    end

    it 'keeps blank lines (including a trailing newline)' do
      b = described_class.new(app, text: "a\n\nb\n")
      expect(b.preferred_height(80)).to eq(4) # a, '', b, ''
    end

    it 'truncates each line to the rect width' do
      b = described_class.new(app, text: '0123456789ABCDEF')
      b.layout(Potty::Layout::Rect.new(0, 0, 10, 1))
      b.render(window)
      expect(window.strs).to eq(['0123456789'])
    end

    it 'does not render rows beyond the rect height' do
      block.layout(Potty::Layout::Rect.new(0, 0, 40, 2)) # only 2 of 3 lines fit
      block.render(window)
      expect(window.strs).to eq(['line one', 'line two'])
    end
  end

  describe 'word wrap (wrap: true)' do
    it 'wraps a long line to the width on word boundaries' do
      b = described_class.new(app, text: 'the quick brown fox jumps', wrap: true)
      # width 10: "the quick" (9) | "brown fox" (9) | "jumps" (5)
      expect(b.preferred_height(10)).to eq(3)
      b.layout(Potty::Layout::Rect.new(0, 0, 10, 5))
      b.render(window)
      expect(window.strs).to eq(['the quick', 'brown fox', 'jumps'])
    end

    it 'hard-breaks a word longer than the width' do
      b = described_class.new(app, text: 'abcdefghij', wrap: true)
      expect(b.preferred_height(4)).to eq(3) # abcd | efgh | ij
      b.layout(Potty::Layout::Rect.new(0, 0, 4, 5))
      b.render(window)
      expect(window.strs).to eq(%w[abcd efgh ij])
    end

    it 'wraps each newline-delimited paragraph independently' do
      b = described_class.new(app, text: "aa bb\ncc dd", wrap: true)
      expect(b.preferred_height(5)).to eq(2) # "aa bb" | "cc dd"
    end
  end

  it 'exposes mutable text' do
    b = described_class.new(app, text: 'x')
    b.text = "a\nb"
    expect(b.preferred_height(80)).to eq(2)
  end
end
