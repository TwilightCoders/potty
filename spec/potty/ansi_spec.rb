# frozen_string_literal: true

RSpec.describe Potty::Ansi do
  def style(**o)
    Potty::Style.new({ fg: :default, bg: :default }.merge(o))
  end

  it 'maps fg/bg symbolic colours to SGR codes' do
    expect(described_class.sgr(style(fg: :green))).to eq("\e[32;49m")
    expect(described_class.sgr(style(fg: :default, bg: :cyan))).to eq("\e[39;46m")
  end

  it 'includes attribute codes before colours' do
    expect(described_class.sgr(style(fg: :red, bold: true))).to eq("\e[1;31;49m")
    expect(described_class.sgr(style(fg: :white, underline: true, reverse: true))).to eq("\e[4;7;37;49m")
  end

  it 'returns a reset for a nil style' do
    expect(described_class.sgr(nil)).to eq("\e[0m")
    expect(described_class.reset).to eq("\e[0m")
  end

  it 'falls back to defaults for unknown colours' do
    expect(described_class.sgr(style(fg: :chartreuse))).to eq("\e[39;49m")
  end
end
