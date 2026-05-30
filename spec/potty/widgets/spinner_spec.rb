# frozen_string_literal: true

RSpec.describe Potty::Widgets::Spinner do
  let(:app) { PottySpec.app }
  subject(:spinner) { described_class.new(app, label: 'working') }

  it 'starts active and non-focusable' do
    expect(spinner.active?).to be(true)
    expect(spinner.state).to eq(:active)
    expect(spinner.can_focus?).to be(false)
  end

  it 'allows live label updates' do
    spinner.label = 'adopting 11/16'
    expect(spinner.label).to eq('adopting 11/16')
  end

  describe '#complete!' do
    it 'freezes to success: state, color flip, stops animating' do
      spinner.complete!(:success)
      expect(spinner.state).to eq(:success)
      expect(spinner.color).to eq(:success)
      expect(spinner.active?).to be(false)
    end

    it 'maps failure -> :error and cancelled -> :dim' do
      f = described_class.new(app)
      f.complete!(:failure)
      expect(f.color).to eq(:error)

      c = described_class.new(app)
      c.complete!(:cancelled)
      expect(c.color).to eq(:dim)
    end

    it 'is idempotent — first result wins' do
      spinner.complete!(:success)
      spinner.complete!(:failure)
      expect(spinner.state).to eq(:success)
    end

    it 'emits :complete with the result' do
      seen = nil
      spinner.on(:complete) { |r| seen = r }
      spinner.complete!(:cancelled)
      expect(seen).to eq(:cancelled)
    end

    it 'still allows label updates after completing' do
      spinner.complete!(:success)
      spinner.label = 'done'
      expect(spinner.label).to eq('done')
    end
  end

  it 'stops advancing frames once completed' do
    t0 = Time.at(100)
    spinner.tick(t0)
    spinner.complete!(:success)
    # tick after completion is a no-op; no error and state holds
    expect { spinner.tick(t0 + 1) }.not_to raise_error
    expect(spinner.active?).to be(false)
  end
end
