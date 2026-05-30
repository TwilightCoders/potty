# frozen_string_literal: true

RSpec.describe Potty::Animator do
  let(:app) { PottySpec.app }
  let(:t0) { Time.at(1_000) }

  # 4-frame looping sprite at 10fps -> 0.1s per frame.
  let(:loop_sprite) do
    Potty::Sprite.new(:loop, frames: %w[a b c d], fps: 10, mode: :loop)
  end

  let(:once_sprite) do
    Potty::Sprite.new(:once, frames: %w[x y z], fps: 10, mode: :once)
  end

  subject(:animator) { described_class.new(app) }

  it 'activates and plays the first sprite added' do
    animator.add_sprite(loop_sprite)
    expect(animator.current).to eq(:loop)
    expect(animator).to be_playing
    expect(animator.frame_index).to eq(0)
  end

  it 'does not advance before a full frame duration elapses' do
    animator << loop_sprite
    animator.tick(t0)
    animator.tick(t0 + 0.05)
    expect(animator.frame_index).to eq(0)
  end

  it 'advances one frame per fps interval' do
    animator << loop_sprite
    animator.tick(t0)
    animator.tick(t0 + 0.1)
    expect(animator.frame_index).to eq(1)
    animator.tick(t0 + 0.2)
    expect(animator.frame_index).to eq(2)
  end

  it 'wraps a looping sprite' do
    animator << loop_sprite
    animator.tick(t0)
    animator.tick(t0 + 0.4) # 4 frames -> back to 0
    expect(animator.frame_index).to eq(0)
  end

  it 'catches up multiple frames when the loop ran slow' do
    animator << loop_sprite
    animator.tick(t0)
    animator.tick(t0 + 0.25) # 2.5 frames -> floor 2
    expect(animator.frame_index).to eq(2)
  end

  it 'stops a :once sprite on the last frame and fires on_complete' do
    done = nil
    animator.on_complete = ->(a) { done = a.frame_index }
    animator << once_sprite
    animator.tick(t0)
    animator.tick(t0 + 1.0) # would overshoot; clamps to last frame
    expect(animator.frame_index).to eq(2)
    expect(animator).not_to be_playing
    expect(done).to eq(2)
  end

  it 'never overshoots the :once endpoint even with exact stepping' do
    animator << once_sprite
    animator.tick(t0)
    animator.tick(t0 + 0.1)
    animator.tick(t0 + 0.2)
    animator.tick(t0 + 0.3)
    expect(animator.frame_index).to eq(2)
    expect(animator).not_to be_playing
  end

  it 'swaps the active sprite and restarts on play' do
    animator << loop_sprite
    animator << once_sprite
    animator.tick(t0)
    animator.tick(t0 + 0.1)
    expect(animator.frame_index).to eq(1)

    animator.play(:once)
    expect(animator.current).to eq(:once)
    expect(animator.frame_index).to eq(0)
  end

  it 'ignores play for an unknown sprite' do
    animator << loop_sprite
    animator.play(:missing)
    expect(animator.current).to eq(:loop)
  end

  it 'reports preferred_height from the active sprite' do
    tall = Potty::Sprite.new(:tall, frames: ["1\n2\n3"])
    animator << tall
    expect(animator.preferred_height(80)).to eq(3)
  end

  it 'does not tick when stopped' do
    animator << loop_sprite
    animator.stop
    animator.tick(t0)
    animator.tick(t0 + 0.5)
    expect(animator.frame_index).to eq(0)
  end
end
