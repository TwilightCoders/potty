# frozen_string_literal: true

RSpec.describe Potty::Events do
  let(:klass) { Class.new { include Potty::Events } }
  subject(:obj) { klass.new }

  it 'invokes a registered listener with args' do
    seen = nil
    obj.on(:change) { |v| seen = v }
    expect(obj.emit(:change, 42)).to be(true)
    expect(seen).to eq(42)
  end

  it 'returns self from on/off for chaining' do
    expect(obj.on(:a) {}).to equal(obj)
    expect(obj.off(:a)).to equal(obj)
  end

  it 'fires multiple listeners in registration order' do
    order = []
    obj.on(:e) { order << :first }
    obj.on(:e) { order << :second }
    obj.emit(:e)
    expect(order).to eq(%i[first second])
  end

  it 'returns false when emitting with no listeners' do
    expect(obj.emit(:nobody)).to be(false)
  end

  it 'ignores a bare on with no block' do
    expect(obj.on(:x)).to equal(obj)
    expect(obj.listeners?(:x)).to be(false)
  end

  it 'removes one event with off(event)' do
    obj.on(:a) { raise 'should not fire' }
    obj.off(:a)
    expect(obj.emit(:a)).to be(false)
  end

  it 'removes all events with bare off' do
    obj.on(:a) {}
    obj.on(:b) {}
    obj.off
    expect(obj.listeners?(:a)).to be(false)
    expect(obj.listeners?(:b)).to be(false)
  end

  it 'symbolizes event names' do
    seen = false
    obj.on('go') { seen = true }
    obj.emit(:go)
    expect(seen).to be(true)
  end
end
