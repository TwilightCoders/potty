# frozen_string_literal: true

# CursesSurface's erase/force_repaint logic is exercised without a real screen
# by injecting a fake WindowManager whose stdscr records erase/clear calls.
# (start/present touch the global Curses screen and need a TTY, so they're not
# covered here.)
RSpec.describe Potty::Surfaces::CursesSurface do
  let(:stdscr) do
    Object.new.tap do |s|
      s.instance_variable_set(:@calls, [])
      def s.calls = @calls
      def s.erase = @calls << :erase
      def s.clear = @calls << :clear
    end
  end

  let(:wm) do
    sc = stdscr
    Object.new.tap do |w|
      w.define_singleton_method(:stdscr) { sc }
    end
  end

  subject(:surface) { described_class.new(wm, Potty::Theme.new) }

  describe '#erase' do
    it 'uses damage-tracked werase on a normal frame' do
      surface.erase
      expect(stdscr.calls).to eq([:erase])
    end

    it 'clears the cursor request each frame' do
      surface.place_cursor(0, 0)
      surface.erase
      expect(surface.send(:cursor_request)).to be_nil
    end
  end

  describe '#force_repaint! (the ghost-fragment fix)' do
    it 'makes the very next erase a full wclear, then reverts' do
      surface.force_repaint!
      surface.erase
      surface.erase
      # First erase after arming = clear (full repaint); subsequent = werase.
      expect(stdscr.calls).to eq(%i[clear erase])
    end

    it 'is a one-shot — a second forced frame re-arms it' do
      surface.force_repaint!
      surface.erase
      surface.force_repaint!
      surface.erase
      expect(stdscr.calls).to eq(%i[clear clear])
    end
  end
end
