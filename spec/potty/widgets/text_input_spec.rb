# frozen_string_literal: true

RSpec.describe Potty::Widgets::TextInput do
  let(:app) { PottySpec.app }
  subject(:input) { described_class.new(app) }

  def type(str)
    str.each_char { |c| input.handle_key(c.ord) }
  end

  it 'is focusable' do
    expect(input.can_focus?).to be(true)
  end

  it 'inserts printable characters' do
    type('hello')
    expect(input.text).to eq('hello')
  end

  it 'fires on_change on each mutation' do
    seen = []
    input.on_change = ->(t) { seen << t }
    type('ab')
    expect(seen).to eq(%w[a ab])
  end

  it 'backspaces at the caret' do
    type('abc')
    input.handle_key(127)
    expect(input.text).to eq('ab')
  end

  it 'moves the caret and inserts mid-string' do
    type('ac')
    input.handle_key(Curses::Key::LEFT)
    input.handle_key('b'.ord)
    expect(input.text).to eq('abc')
  end

  it 'deletes forward' do
    type('abc')
    input.handle_key(Potty::Keys::LEFT)
    input.handle_key(Potty::Keys::LEFT)
    input.handle_key(Potty::Keys::DELETE)
    expect(input.text).to eq('ac')
  end

  it 'jumps home and end' do
    type('abc')
    input.handle_key(Potty::Keys::HOME)
    input.handle_key('X'.ord)
    expect(input.text).to eq('Xabc')
    input.handle_key(Potty::Keys::END_)
    input.handle_key('Y'.ord)
    expect(input.text).to eq('XabcY')
  end

  it 'enforces max_length' do
    input.max_length = 3
    type('abcdef')
    expect(input.text).to eq('abc')
  end

  it 'assigns text= and clamps the caret' do
    type('abcdef')
    input.text = 'hi'
    expect(input.text).to eq('hi')
    input.handle_key('!'.ord)
    expect(input.text).to eq('hi!')
  end

  it 'ignores backspace at the start' do
    input.handle_key(127)
    expect(input.text).to eq('')
  end

  it 'returns false for unhandled keys' do
    expect(input.handle_key(Curses::Key::F1)).to be(false)
  end

  describe 'hardware cursor on render' do
    # A fake app/theme/window just rich enough to render against; the window
    # records place_cursor calls so we can assert the caret request.
    let(:theme) do
      Object.new.tap do |t|
        def t.style(_key, **_opts) = 0
      end
    end
    let(:render_app) do
      th = theme
      Object.new.tap { |a| a.define_singleton_method(:theme) { th } }
    end
    let(:window) do
      Object.new.tap do |w|
        w.instance_variable_set(:@cursors, [])
        def w.cursors = @cursors
        def w.setpos(_y, _x) = nil
        def w.addstr(_s) = nil
        def w.attron(_a) = (yield if block_given?)
        def w.place_cursor(row, col, shape:) = @cursors << [row, col, shape]
      end
    end
    let(:rect) { Potty::Layout::Rect.new(4, 1, 10, 1) } # Rect.new(x, y, w, h)
    subject(:field) { described_class.new(render_app, text: 'hi', cursor_shape: :bar) }

    it 'requests the hardware cursor at the caret when focused' do
      field.focus
      field.layout(rect)
      field.render(window)
      # place_cursor(row = rect.y, col = rect.x + caret); caret sits past "hi"
      expect(window.cursors).to eq([[1, 6, :bar]])
    end

    it 'does not request a cursor when unfocused' do
      field.layout(rect)
      field.render(window)
      expect(window.cursors).to be_empty
    end

    it 'degrades silently when the window has no place_cursor' do
      bare = Object.new.tap do |w|
        def w.setpos(_y, _x) = nil
        def w.addstr(_s) = nil
        def w.attron(_a) = (yield if block_given?)
      end
      field.focus
      field.layout(rect)
      expect { field.render(bare) }.not_to raise_error
    end
  end
end
