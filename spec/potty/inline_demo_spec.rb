# frozen_string_literal: true

# Regression guard for the shipped bin/potty_inline_demo. The interactive
# prompts need a TTY (live-validated), but the passive DeployView is fully
# checkable against a fake surface: it must build, render, and resolve both
# spinners then quit on its tick schedule.

load File.expand_path('../../bin/potty_inline_demo', __dir__) unless defined?(PottyInlineDemo)

RSpec.describe 'bin/potty_inline_demo' do
  let(:surface) do
    Object.new.tap do |s|
      def s.size = [3, 80]
      def s.erase = nil
      def s.setpos(*) = nil
      def s.addstr(*) = nil
      def s.attron(*) = (yield if block_given?)
      def s.present = nil
    end
  end

  let(:app) do
    surf = surface
    Object.new.tap do |a|
      theme = Object.new
      def theme.style(_n, **_o) = Potty::Style.new(fg: :default, bg: :default)
      def theme.[](_k) = 0
      def theme.attr(_k, **_o) = 0
      a.define_singleton_method(:theme) { theme }
      a.define_singleton_method(:surface) { surf }
      a.instance_variable_set(:@quit, false)
      a.define_singleton_method(:quit) { @quit = true }
      a.define_singleton_method(:quit?) { @quit }
    end
  end

  subject(:view) { PottyInlineDemo::DeployView.new(app).tap { |v| v.activate(app) } }

  it 'builds and renders without error' do
    expect { view.render }.not_to raise_error
  end

  it 'resolves both spinners on schedule and quits' do
    build  = view.instance_variable_get(:@build)
    upload = view.instance_variable_get(:@upload)
    t0 = Time.at(100)

    view.tick(t0)
    expect(build.active?).to be(true)
    expect(upload.active?).to be(true)

    view.tick(t0 + 1.2)
    expect(build.active?).to be(false)  # completed past 1.0s
    expect(upload.active?).to be(true)

    view.tick(t0 + 2.2)
    expect(upload.active?).to be(false) # completed past 2.0s

    view.tick(t0 + 2.7)
    expect(app.quit?).to be(true)       # quits past 2.6s
  end
end
