# frozen_string_literal: true

# Regression guard for the shipped bin/cursed_demo: every demo view must
# build, lay out, render, and tick against a fake terminal, and the form's
# event wiring must hold. Keeps the demo honest as widgets evolve.

load File.expand_path('../../bin/cursed_demo', __dir__) unless defined?(CursedDemo)

RSpec.describe 'bin/cursed_demo' do
  let(:window) do
    Object.new.tap do |w|
      def w.setpos(*) = nil
      def w.addstr(*) = nil
      def w.attron(*) = (yield if block_given?)
      def w.erase = nil
    end
  end

  let(:wm) do
    win = window
    Object.new.tap do |m|
      m.define_singleton_method(:max_y) { 24 }
      m.define_singleton_method(:max_x) { 80 }
      m.define_singleton_method(:stdscr) { win }
      m.define_singleton_method(:refresh_all) {}
    end
  end

  let(:app) do
    manager = wm
    Object.new.tap do |a|
      theme = Object.new
      def theme.[](_k) = 0
      def theme.attr(_k, **_o) = 0
      a.define_singleton_method(:theme) { theme }
      a.define_singleton_method(:window_manager) { manager }
      a.define_singleton_method(:push_view) { |*| }
      a.define_singleton_method(:pop_view) { |*| }
      a.define_singleton_method(:quit) {}
    end
  end

  %i[MenuView FormView MotionView LayoutView].each do |view_name|
    it "#{view_name} builds, lays out, renders, and ticks" do
      view = CursedDemo.const_get(view_name).new(app)
      view.activate(app)
      expect { view.render }.not_to raise_error
      expect { view.tick(Time.at(100)) }.not_to raise_error
    end
  end

  describe 'FormView event wiring' do
    subject(:form) { CursedDemo::FormView.new(app).tap { |v| v.activate(app) } }

    it 'updates the preview label as the name is typed' do
      input = form.instance_variable_get(:@name)
      preview = form.instance_variable_get(:@preview)
      'Dale'.each_char { |c| input.handle_key(c.ord) }
      expect(preview.text).to eq('Hello, Dale')
    end

    it 'hides the feature checkboxes when notifications toggle off' do
      notify = form.instance_variable_get(:@notify)
      feats = form.instance_variable_get(:@feats)
      notify.handle_key(Cursed::Keys::SPACE)
      expect(feats.visible?).to be(false)
    end
  end
end
