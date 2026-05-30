# frozen_string_literal: true

RSpec.describe Cursed::Widgets::TextInput do
  let(:app) { CursedSpec.app }
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
    input.handle_key(Cursed::Keys::LEFT)
    input.handle_key(Cursed::Keys::LEFT)
    input.handle_key(Cursed::Keys::DELETE)
    expect(input.text).to eq('ac')
  end

  it 'jumps home and end' do
    type('abc')
    input.handle_key(Cursed::Keys::HOME)
    input.handle_key('X'.ord)
    expect(input.text).to eq('Xabc')
    input.handle_key(Cursed::Keys::END_)
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
end
