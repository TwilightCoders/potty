# frozen_string_literal: true

RSpec.describe Potty::Sprite do
  subject(:sprite) do
    described_class.new(:demo, frames: ["a\nbb", "ccc"], fps: 10, mode: :once)
  end

  it 'symbolizes the name' do
    expect(sprite.name).to eq(:demo)
  end

  it 'reports frame count' do
    expect(sprite.frame_count).to eq(2)
  end

  it 'returns frame lines preserving structure' do
    expect(sprite.frame_lines(0)).to eq(%w[a bb])
  end

  it 'preserves trailing blank lines' do
    s = described_class.new(:x, frames: ["top\n"])
    expect(s.frame_lines(0)).to eq(['top', ''])
  end

  it 'measures height as the tallest frame' do
    expect(sprite.height).to eq(2)
  end

  it 'measures width as the widest line' do
    expect(sprite.width).to eq(3)
  end

  it 'rejects empty frames' do
    expect { described_class.new(:x, frames: []) }.to raise_error(ArgumentError)
  end

  it 'rejects unknown modes' do
    expect { described_class.new(:x, frames: ['a'], mode: :bogus) }
      .to raise_error(ArgumentError)
  end

  it 'freezes frames against mutation' do
    expect { sprite.frames << 'nope' }.to raise_error(FrozenError)
  end
end
