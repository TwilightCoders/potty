# frozen_string_literal: true

RSpec.describe Potty::Widgets::Label do
  # Fake theme: any color -> 0, attr -> 0.
  let(:theme) do
    Object.new.tap do |t|
      def t.[](_key) = 0
      def t.attr(_key, **_opts) = 0
    end
  end

  let(:app) do
    th = theme
    Object.new.tap { |a| a.define_singleton_method(:theme) { th } }
  end

  # Fake window recording draw ops; attron yields its block.
  let(:window) do
    Object.new.tap do |w|
      w.instance_variable_set(:@ops, [])
      def w.ops = @ops
      def w.setpos(y, x) = @ops << [:setpos, y, x]
      def w.addstr(str) = @ops << [:addstr, str]
      def w.attron(_attr) = (yield if block_given?)
    end
  end

  let(:rect) { Potty::Layout::Rect.new(2, 3, 10, 1) }
  subject(:label) { described_class.new(app, text: 'Path:', color: :info) }

  it 'is not focusable' do
    expect(label.can_focus?).to be(false)
  end

  it 'is single-line' do
    expect(label.preferred_height(80)).to eq(1)
  end

  it 'exposes mutable text and color' do
    label.text = 'Updated'
    label.color = :warning
    expect(label.text).to eq('Updated')
    expect(label.color).to eq(:warning)
  end

  it 'renders its text at the rect origin' do
    label.layout(rect)
    label.render(window)
    expect(window.ops).to include([:setpos, 3, 2], [:addstr, 'Path:'])
  end

  it 'truncates to the rect width' do
    label.text = '0123456789ABCDEF'
    label.layout(rect)
    label.render(window)
    expect(window.ops).to include([:addstr, '0123456789']) # width 10
  end

  it 'does not draw without a rect' do
    label.render(window)
    expect(window.ops).to be_empty
  end

  it 'does not draw when hidden' do
    label.layout(rect)
    label.hide
    label.render(window)
    expect(window.ops).to be_empty
  end
end
