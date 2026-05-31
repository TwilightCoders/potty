# frozen_string_literal: true

RSpec.describe Potty::View do
  # A view that records, each time build_layout runs, whether the surface was
  # reachable at that moment — the crux of the "nil surface during build_layout"
  # bug: build_layout must run only after the Application has a surface.
  let(:view_class) do
    Class.new(described_class) do
      attr_reader :build_count, :surface_seen

      def build_layout
        @build_count = (@build_count || 0) + 1
        @surface_seen = !@app.surface.nil?
      end
    end
  end

  let(:surface) { Object.new.tap { |s| def s.size = [10, 40] } }

  # Construction-time app has NO surface (mirrors Application#run building the
  # view before the surface); activation-time app does.
  let(:bare_app) { Object.new.tap { |a| def a.surface = nil } }
  let(:live_app) do
    s = surface
    Object.new.tap { |a| a.define_singleton_method(:surface) { s } }
  end

  it 'does not build the layout at construction time' do
    view = view_class.new(bare_app)
    expect(view.build_count).to be_nil
  end

  it 'builds the layout on first activate, with the surface available' do
    view = view_class.new(bare_app)
    view.activate(live_app)
    expect(view.build_count).to eq(1)
    expect(view.surface_seen).to be(true)
  end

  it 'builds the layout only once across repeated activations' do
    view = view_class.new(bare_app)
    view.activate(live_app)
    view.activate(live_app)
    expect(view.build_count).to eq(1)
  end
end
