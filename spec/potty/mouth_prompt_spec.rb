# frozen_string_literal: true

# Logic of the inline prompt views backing Mouth.ask/confirm/choose, driven
# through handle_key the way the event loop would (no TTY / raw I/O involved —
# that layer is exercised live, like CursesSurface).
RSpec.describe Potty::Mouth::Prompt do
  let(:app) { Object.new.tap { |a| def a.quit = nil } }

  describe 'inline layout (spacing 0 so nothing clips out of the region)' do
    def app_sized(rows)
      surf = Object.new
      surf.define_singleton_method(:size) { [rows, 80] }
      Object.new.tap do |a|
        a.define_singleton_method(:surface) { surf }
        a.define_singleton_method(:quit) {}
      end
    end

    it 'lays the Ask field on the last row of its 2-row region (not clipped)' do
      a = app_sized(2)
      view = Potty::Mouth::Prompt::Ask.new(a, prompt: 'Name?')
      view.activate(a)
      expect(view.instance_variable_get(:@field).rect.y).to eq(1)
    end

    it 'keeps the Choose radio inside an (options+1)-row region' do
      a = app_sized(4) # label + 3 options
      view = Potty::Mouth::Prompt::Choose.new(a, prompt: 'Pick', options: %i[a b c])
      view.activate(a)
      radio = view.instance_variable_get(:@radio)
      expect(radio.rect.y).to eq(1)                       # right after the label
      expect(radio.rect.y + radio.preferred_height(80)).to be <= 4
    end
  end

  describe Potty::Mouth::Prompt::Ask do
    subject(:view) { described_class.new(app, prompt: 'Name?', default: 'x') }

    it 'starts focused on the field with the default text' do
      field = view.instance_variable_get(:@field)
      expect(field.focused).to be(true)
      expect(field.text).to eq('x')
    end

    it 'captures the typed text on Enter' do
      view.instance_variable_get(:@field).text = ''
      'hi'.each_char { |c| view.handle_key(c.ord) }
      view.handle_key(Potty::Keys::ENTER)
      expect(view.result).to eq('hi')
    end

    it 'returns nil on ESC' do
      view.handle_escape
      expect(view.result).to be_nil
    end
  end

  describe Potty::Mouth::Prompt::Confirm do
    it 'returns true on y, false on n' do
      yes = described_class.new(app, prompt: 'Go?')
      yes.handle_key('y'.ord)
      expect(yes.result).to be(true)

      no = described_class.new(app, prompt: 'Go?')
      no.handle_key('n'.ord)
      expect(no.result).to be(false)
    end

    it 'uses the default on Enter and on ESC' do
      d1 = described_class.new(app, prompt: 'Go?', default: true)
      d1.handle_key(Potty::Keys::ENTER)
      expect(d1.result).to be(true)

      d2 = described_class.new(app, prompt: 'Go?', default: false)
      d2.handle_escape
      expect(d2.result).to be(false)
    end
  end

  describe Potty::Mouth::Prompt::Choose do
    subject(:view) { described_class.new(app, prompt: 'Pick', options: %i[a b c]) }

    it 'returns the cursor option on Enter, after arrowing' do
      view.handle_key(Potty::Keys::DOWN) # a -> b
      view.handle_key(Potty::Keys::ENTER)
      expect(view.result).to eq(:b)
    end

    it 'returns nil on ESC' do
      view.handle_escape
      expect(view.result).to be_nil
    end

    it 'accepts {value:, label:} options' do
      v = described_class.new(app, prompt: 'Pick', options: [{ value: :x, label: 'X' }, { value: :y, label: 'Y' }])
      v.handle_key(Potty::Keys::ENTER)
      expect(v.result).to eq(:x)
    end
  end
end
