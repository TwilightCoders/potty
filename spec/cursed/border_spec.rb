# frozen_string_literal: true

RSpec.describe Cursed::Border do
  # Fake window collecting addstr strings.
  let(:window) do
    Object.new.tap do |w|
      w.instance_variable_set(:@strs, [])
      def w.strs = @strs
      def w.setpos(_y, _x) = nil
      def w.addstr(s) = @strs << s
      def w.attron(_a) = (yield if block_given?)
    end
  end

  let(:rect) { Cursed::Layout::Rect.new(0, 0, 6, 4) }

  it 'draws top, sides, and bottom with single-style corners' do
    described_class.draw(window, rect)
    top = window.strs.first
    bottom = window.strs.last
    expect(top).to eq("┌────┐")    # ┌────┐
    expect(bottom).to eq("└────┘") # └────┘
    expect(window.strs).to include("│") # vertical edges
  end

  it 'uses the requested style' do
    described_class.draw(window, rect, style: :rounded)
    expect(window.strs.first).to start_with("╭") # ╭
  end

  it 'centers a title on the top edge' do
    described_class.draw(window, Cursed::Layout::Rect.new(0, 0, 12, 4), title: 'Hi')
    expect(window.strs).to include(' Hi ')
  end

  it 'no-ops on a degenerate rect' do
    described_class.draw(window, Cursed::Layout::Rect.new(0, 0, 1, 1))
    expect(window.strs).to be_empty
  end
end
