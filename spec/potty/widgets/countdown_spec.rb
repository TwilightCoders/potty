# frozen_string_literal: true

RSpec.describe Potty::Widgets::Countdown do
  let(:app) { PottySpec.app }
  let(:t0) { Time.at(2_000) }

  it 'reports full seconds before the first tick' do
    cd = described_class.new(app, seconds: 3)
    expect(cd.remaining).to eq(3)
  end

  it 'starts its clock on the first tick, not at construction' do
    cd = described_class.new(app, seconds: 3)
    cd.tick(t0)
    expect(cd.remaining).to eq(3)
  end

  it 'counts down by whole seconds' do
    cd = described_class.new(app, seconds: 3)
    cd.tick(t0)
    cd.tick(t0 + 1)
    expect(cd.remaining).to eq(2)
    cd.tick(t0 + 2.4)
    expect(cd.remaining).to eq(1)
  end

  it 'expires once at zero and fires on_expire' do
    fired = 0
    cd = described_class.new(app, seconds: 2, on_expire: ->(_) { fired += 1 })
    cd.tick(t0)
    cd.tick(t0 + 1)
    expect(cd).not_to be_expired
    cd.tick(t0 + 2)
    expect(cd).to be_expired
    expect(cd.remaining).to eq(0)
    cd.tick(t0 + 3) # already expired, no second fire
    expect(fired).to eq(1)
  end

  it 'does not advance after stop' do
    cd = described_class.new(app, seconds: 3)
    cd.tick(t0)
    cd.stop
    cd.tick(t0 + 5)
    expect(cd).not_to be_expired
  end

  it 'restarts from the top on start' do
    cd = described_class.new(app, seconds: 2)
    cd.tick(t0)
    cd.tick(t0 + 2)
    expect(cd).to be_expired
    cd.start
    cd.tick(t0 + 10)
    expect(cd.remaining).to eq(2)
    expect(cd).not_to be_expired
  end

  it 'accepts a custom format' do
    cd = described_class.new(app, seconds: 5, format: ->(r) { "#{r} left" })
    expect(cd.instance_variable_get(:@format).call(5)).to eq('5 left')
  end
end
