# frozen_string_literal: true

# Verifies the Application arms a full repaint (Surface#force_repaint!) at the
# moments damage tracking can't be trusted — view transitions and resize —
# which is what fixes the multi-byte-glyph ghost-fragment bug on pop_view.
RSpec.describe Potty::Application do
  let(:surface) do
    Object.new.tap do |s|
      s.instance_variable_set(:@repaints, 0)
      def s.repaints = @repaints
      def s.force_repaint! = @repaints += 1
      def s.erase = nil
      def s.present = nil
      def s.size = [24, 80]
      def s.handle_resize = nil
      def s.start = nil
    end
  end

  def fake_view
    Object.new.tap do |v|
      def v.activate(_app) = nil
      def v.deactivate = nil
      def v.render = nil
      def v.tick(_now) = nil
      def v.layout_widgets = nil
    end
  end

  subject(:app) { described_class.new }

  before { app.instance_variable_set(:@surface, surface) }

  it 'arms a repaint on push_view' do
    app.push_view(fake_view)
    expect(surface.repaints).to eq(1)
  end

  it 'arms a repaint on pop_view' do
    app.push_view(fake_view)
    app.push_view(fake_view)
    expect { app.pop_view }.to change(surface, :repaints).by(1)
  end

  it 'does not pop (or repaint) the last view' do
    app.push_view(fake_view)
    expect { app.pop_view }.not_to change(surface, :repaints)
  end

  it 'arms a repaint on resume' do
    app.push_view(fake_view)
    expect { app.resume }.to change(surface, :repaints).by(1)
  end

  it 'arms a repaint on resize' do
    app.push_view(fake_view)
    expect { app.send(:resize) }.to change(surface, :repaints).by(1)
  end

  describe 'modal pop result' do
    it 'calls the pusher\'s on_result with the pop result' do
      app.push_view(fake_view) # root
      got = nil
      app.push_view(fake_view, on_result: ->(r) { got = r })
      app.pop_view(:chosen)
      expect(got).to eq(:chosen)
    end

    it 'delivers nil on a bare pop (cancel)' do
      app.push_view(fake_view)
      got = :untouched
      app.push_view(fake_view, on_result: ->(r) { got = r })
      app.pop_view
      expect(got).to be_nil
    end

    it 'does not fire a handler for a view pushed without one' do
      app.push_view(fake_view)
      app.push_view(fake_view) # no on_result
      expect { app.pop_view(:x) }.not_to raise_error
    end
  end

  describe '#schedule' do
    let(:t0) { Time.new(2026, 5, 30, 12, 0, 0) }

    before { app.push_view(fake_view) }

    it 'fires a scheduled block after the interval elapses on the tick clock' do
      fired = false
      app.schedule(5) { fired = true }
      app.tick(t0)        # arm
      app.tick(t0 + 4)
      expect(fired).to be(false)
      app.tick(t0 + 5)
      expect(fired).to be(true)
    end

    it 'fires only once' do
      count = 0
      app.schedule(1) { count += 1 }
      app.tick(t0)
      app.tick(t0 + 2)
      app.tick(t0 + 3)
      expect(count).to eq(1)
    end

    it 'can be cancelled before firing' do
      fired = false
      task = app.schedule(5) { fired = true }
      app.tick(t0)
      task.cancel
      app.tick(t0 + 10)
      expect(fired).to be(false)
    end
  end
end
