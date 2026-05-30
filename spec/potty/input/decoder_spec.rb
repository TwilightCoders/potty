# frozen_string_literal: true

RSpec.describe Potty::Input::Decoder do
  subject(:decoder) { described_class.new(escape_timeout: 0.25) }
  let(:t0) { Time.at(1_000) }
  K = Potty::Keys

  describe 'plain bytes' do
    it 'passes printable characters through as their codes' do
      expect(decoder.feed('hi', t0)).to eq([104, 105])
    end

    it 'passes control codes through (Enter, Backspace, Tab)' do
      expect(decoder.feed("\r", t0)).to eq([K::RETURN])
      expect(decoder.feed("\t", t0)).to eq([K::TAB])
      expect(decoder.feed("", t0)).to eq([127])
    end
  end

  describe 'escape sequences' do
    it 'decodes arrows arriving whole' do
      expect(decoder.feed("\e[A", t0)).to eq([K::UP])
      expect(decoder.feed("\e[B", t0)).to eq([K::DOWN])
      expect(decoder.feed("\e[C", t0)).to eq([K::RIGHT])
      expect(decoder.feed("\e[D", t0)).to eq([K::LEFT])
    end

    it 'decodes SS3 (application-cursor) arrows' do
      expect(decoder.feed("\eOC", t0)).to eq([K::RIGHT])
    end

    it 'decodes home/end/delete and shift-tab' do
      expect(decoder.feed("\e[H", t0)).to eq([K::HOME])
      expect(decoder.feed("\e[4~", t0)).to eq([K::END_])
      expect(decoder.feed("\e[3~", t0)).to eq([K::DELETE])
      expect(decoder.feed("\e[Z", t0)).to eq([K::SHIFT_TAB])
    end

    it 'reassembles a sequence split across feeds' do
      expect(decoder.feed("\e[", t0)).to eq([])      # incomplete — held
      expect(decoder.feed('A', t0)).to eq([K::UP])   # completes
    end

    it 'interleaves sequences with plain text' do
      expect(decoder.feed("a\e[Bz", t0)).to eq([97, K::DOWN, 122])
    end
  end

  describe 'the bare-ESC timeout' do
    it 'holds a lone ESC until the timeout, then emits it' do
      expect(decoder.feed("\e", t0)).to eq([])            # ambiguous — wait
      expect(decoder.feed('', t0 + 0.1)).to eq([])        # still within window
      expect(decoder.feed('', t0 + 0.3)).to eq([K::ESC])  # timed out -> bare ESC
    end

    it 'treats ESC followed by an unrelated byte as bare ESC then that key' do
      expect(decoder.feed("\ex", t0)).to eq([K::ESC, 120])
    end
  end
end
