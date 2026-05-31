# frozen_string_literal: true

require 'stringio'

RSpec.describe Potty::Surfaces::InlineSurface do
  let(:out) { StringIO.new }
  let(:theme) { Potty::Theme.allocate.tap { |t| t.instance_variable_set(:@palette, Potty::Theme::PALETTE) } }
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

  describe 'hardware cursor (place_cursor + DECSCUSR)' do
    it 'shows the cursor and selects its shape when a widget requests it' do
      surface.erase
      surface.place_cursor(0, 3, shape: :bar)
      surface.present
      s = out.string
      expect(s).to include("\e[5 q")  # DECSCUSR: blinking bar
      expect(s).to include("\e[?25h") # cursor shown
    end

    it 'maps shapes to DECSCUSR codes' do
      { block: "\e[1 q", underline: "\e[3 q", bar: "\e[5 q" }.each do |shape, code|
        out.truncate(0); out.rewind
        surface.erase
        surface.place_cursor(0, 0, shape: shape)
        surface.present
        expect(out.string).to include(code)
      end
    end

    it 'hides the cursor on a frame with no request' do
      surface.erase
      surface.present
      expect(out.string).to include("\e[?25l")
    end

    it 'drops the request after a frame (erase clears it)' do
      surface.erase
      surface.place_cursor(0, 2, shape: :bar)
      surface.present
      out.truncate(0); out.rewind
      surface.erase   # next frame: no one asks
      surface.present
      expect(out.string).to include("\e[?25l") # hidden again
      expect(out.string).not_to include("\e[5 q")
    end

    it 'parks the cursor on the requested interior row, then returns to top next frame' do
      surface.erase
      surface.place_cursor(0, 0, shape: :bar) # top row of a 2-line region
      surface.present                          # leaves cursor 1 row up from bottom
      out.truncate(0); out.rewind
      surface.erase
      surface.present
      # Physical cursor was 1 above the bottom, so the walk-back is (rows-1 - 1) = 0:
      # it must NOT emit an upward move from the wrong anchor.
      expect(out.string).not_to include("\e[1A")
    end

    it 'resets the cursor shape to the terminal default on finalize' do
      surface.start
      out.truncate(0); out.rewind
      surface.finalize
      expect(out.string).to include("\e[0 q")
    end
  end

  describe 'styling' do
    it 'wraps styled text in ANSI SGR and resets' do
      surface.erase
      surface.setpos(0, 0)
      surface.attron(Potty::Style.new(fg: :green, bg: :default, bold: true)) do
        surface.addstr('ok')
      end
      surface.present
      s = out.string
      expect(s).to match(/\e\[(?:[0-9;]*;)?1(?:;[0-9;]*)?;32;49m/) # bold + green fg + default bg
      expect(s).to include("\e[0m") # reset
    end

    it 'renders a Spinner in colour through the surface' do
      spinner = Potty::Widgets::Spinner.new(app_with(theme), label: 'go')
      spinner.layout(Potty::Layout::Rect.new(0, 0, 40, 1))
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
