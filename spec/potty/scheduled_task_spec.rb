# frozen_string_literal: true

RSpec.describe Potty::ScheduledTask do
  # A fixed clock so the timer is fully deterministic.
  let(:t0) { Time.new(2026, 5, 30, 12, 0, 0) }

  def at(seconds)
    t0 + seconds
  end

  it 'fires once, the first tick at or after the interval' do
    fired = 0
    task = described_class.new(5, -> { fired += 1 })

    expect(task.tick(t0)).to be(false)      # starts the clock at t0
    expect(task.tick(at(4))).to be(false)   # not yet due
    expect(fired).to eq(0)
    expect(task.tick(at(5))).to be(true)    # due -> fires, drop it
    expect(fired).to eq(1)
    expect(task.fired?).to be(true)
  end

  it 'does not re-fire after firing' do
    fired = 0
    task = described_class.new(1, -> { fired += 1 })
    task.tick(t0)
    task.tick(at(2)) # fires
    task.tick(at(3)) # already fired -> no-op
    expect(fired).to eq(1)
  end

  it 'does not fire if cancelled before it is due' do
    fired = 0
    task = described_class.new(5, -> { fired += 1 })
    task.tick(t0)
    task.cancel
    expect(task.tick(at(10))).to be(true) # drop it
    expect(fired).to eq(0)
    expect(task.cancelled?).to be(true)
  end

  it 'starts its clock on the first tick (robust to a late first frame)' do
    fired = 0
    task = described_class.new(3, -> { fired += 1 })
    # First tick arrives "late" at t0+100; the 3s window is measured from there.
    task.tick(at(100))
    expect(task.tick(at(102))).to be(false)
    expect(task.tick(at(103))).to be(true)
    expect(fired).to eq(1)
  end
end
