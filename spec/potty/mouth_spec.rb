# frozen_string_literal: true

require 'stringio'

RSpec.describe Potty::Mouth do
  # A StringIO that claims to be a TTY, so the styled path is exercised.
  let(:tty)    { StringIO.new.tap { |io| def io.tty? = true } }
  let(:piped)  { StringIO.new } # StringIO#tty? is false

  describe '.say' do
    it 'wraps the line in SGR + reset on a TTY' do
      described_class.say('deploying', :info, out: tty)
      expect(tty.string).to eq("\e[36;49mdeploying\e[0m\n") # cyan
    end

    it 'applies bold' do
      described_class.say('go', :success, bold: true, out: tty)
      expect(tty.string).to start_with("\e[1;32;49m")
    end

    it 'emits plain text (no ANSI) when output is not a TTY' do
      described_class.say('deploying', :info, out: piped)
      expect(piped.string).to eq("deploying\n")
    end

    it 'falls back to :normal for an unknown colour' do
      described_class.say('hi', :chartreuse, out: tty)
      expect(tty.string).to eq("\e[39;49mhi\e[0m\n") # default fg/bg
    end
  end

  describe '.run' do
    # A view that quits on its first tick, so the inline loop runs one frame.
    let(:quitting_view) do
      Class.new(Potty::View) do
        def build_layout = (@widgets = [])
        def tick(now)
          super
          @app.quit
        end
      end
    end

    it 'runs an inline Application and returns the view, framed cleanly' do
      out = StringIO.new
      view = described_class.run(lines: 1, tick_interval: nil, out: out) do |app|
        quitting_view.new(app)
      end
      expect(view).to be_a(Potty::View)
      expect(out.string).to include("\e[?25l") # cursor hidden on start
      expect(out.string).to include("\e[?25h") # cursor restored on finalize
    end

    it 'builds an inline-mode app (no window_manager)' do
      out = StringIO.new
      captured = nil
      described_class.run(lines: 2, tick_interval: nil, out: out) do |app|
        captured = app
        quitting_view.new(app)
      end
      expect(captured.window_manager).to be_nil
      expect(captured.surface).to be_a(Potty::Surfaces::InlineSurface)
    end
  end

  describe '.bleep' do
    it 'stars the middle, keeping first and last' do
      expect(described_class.bleep('damn')).to eq('d**n')
      expect(described_class.bleep('hell')).to eq('h**l')
    end

    it 'leaves very short words alone' do
      expect(described_class.bleep('hi')).to eq('hi')
      expect(described_class.bleep('a')).to eq('a')
    end

    it 'honours a custom bleep char' do
      expect(described_class.bleep('crap', char: '#')).to eq('c##p')
    end
  end
end
