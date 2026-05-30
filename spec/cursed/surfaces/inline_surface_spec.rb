# frozen_string_literal: true

require 'stringio'

RSpec.describe Cursed::Surfaces::InlineSurface do
  let(:out) { StringIO.new }
  let(:theme) { Cursed::Theme.allocate.tap { |t| t.instance_variable_set(:@palette, Cursed::Theme::PALETTE) } }
  subject(:surface) { described_class.new(theme: theme, lines: 2, tick_interval: nil, out: out) }

  it 'reports its region size' do
    expect(surface.size).to eq([2, 80])
  end

  it 'hides the cursor on start and restores it on finalize' do
    surface.start
    expect(out.string).to include("\e[?25l")
    out.truncate(0); out.rewind
    surface.finalize
    expect(out.string).to include("\e[?25h")
  end

  describe 'presenting a frame' do
    it 'clears each region line and writes the buffered text' do
      surface.erase
      surface.setpos(0, 0)
      surface.addstr('hello')
      surface.setpos(1, 0)
      surface.addstr('world')
      surface.present
      s = out.string
      expect(s).to include("\r\e[2K") # per-line clear
      expect(s).to include('hello')
      expect(s).to include('world')
    end

    it 'moves the cursor back up to the region top on a second present' do
      surface.erase
      surface.present       # primes
      out.truncate(0); out.rewind
      surface.present       # second frame
      expect(out.string).to include("\e[1A") # up (rows - 1) for a 2-line region
    end

    it 'clips text to the column width' do
      narrow = described_class.new(theme: theme, lines: 1, tick_interval: nil, out: out)
      narrow.instance_variable_set(:@cols, 5)
      narrow.erase
      narrow.setpos(0, 0)
      narrow.addstr('abcdefghij')
      narrow.present
      expect(out.string).to include('abcde')
      expect(out.string).not_to include('abcdef')
    end
  end

  describe 'styling' do
    it 'wraps styled text in ANSI SGR and resets' do
      surface.erase
      surface.setpos(0, 0)
      surface.attron(Cursed::Style.new(fg: :green, bg: :default, bold: true)) do
        surface.addstr('ok')
      end
      surface.present
      s = out.string
      expect(s).to match(/\e\[(?:[0-9;]*;)?1(?:;[0-9;]*)?;32;49m/) # bold + green fg + default bg
      expect(s).to include("\e[0m") # reset
    end

    it 'renders a Spinner in colour through the surface' do
      spinner = Cursed::Widgets::Spinner.new(app_with(theme), label: 'go')
      spinner.layout(Cursed::Layout::Rect.new(0, 0, 40, 1))
      spinner.complete!(:success) # fixed checkmark, :success colour
      surface.erase
      spinner.render(surface)
      surface.present
      expect(out.string).to include('go')
      expect(out.string).to include('32') # green (success) fg SGR
    end
  end

  def app_with(theme)
    Object.new.tap { |a| a.define_singleton_method(:theme) { theme } }
  end
end
