# frozen_string_literal: true

RSpec.describe Potty::Widgets::ProgressBar do
  subject(:bar) { described_class.new(width: 10) }

  it 'renders empty at 0' do
    expect(bar.render(0.0)).to eq(' ' * 10)
  end

  it 'renders full at 1.0' do
    expect(bar.render(1.0)).to eq("█" * 10)
  end

  it 'clamps out-of-range progress' do
    expect(bar.render(-1.0)).to eq(bar.render(0.0))
    expect(bar.render(2.0)).to eq(bar.render(1.0))
  end

  it 'keeps a constant total width' do
    [0.0, 0.13, 0.5, 0.77, 1.0].each do |p|
      expect(bar.render(p).length).to eq(10)
    end
  end

  it 'uses partial block glyphs for sub-cell progress' do
    # half a cell of a 10-wide bar = 0.05 progress -> one partial glyph
    rendered = bar.render(0.05)
    expect(rendered[0]).to eq("▌") # 4/8 block
  end

  it 'wraps with brackets' do
    expect(bar.render_with_brackets(1.0)).to eq("[#{"█" * 10}]")
  end
end
