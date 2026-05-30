# frozen_string_literal: true

require_relative 'style'
require_relative 'theme'
require_relative 'ansi'

module Potty
  # potty's inline voice. A mouth *speaks but doesn't listen* — which is
  # exactly what inline mode is (output-only, no input), so this is the front
  # door to inline rendering, in two sizes:
  #
  #   # one utterance — a styled line, no app:
  #   Potty::Mouth.say("deploying…", :info)
  #
  #   # a sustained conversation — a live, redrawing region of widgets:
  #   Potty::Mouth.run(lines: 2, tick_interval: 40) do |app|
  #     DaemonRestartView.new(app, event_queue: q)   # quits itself when done
  #   end
  #
  # `run` is sugar over Application.new(mode: :inline) — Application stays the
  # engine for both screen modes; Mouth is just the inline half with a name
  # that fits. Colour is dropped when output isn't a TTY, so logs stay clean.
  module Mouth
    module_function

    # Run a live inline region: build an inline Application, hand it to the
    # block to construct the root view, and run until the view calls quit.
    # Returns the view (so the caller can read its final state). The block
    # receives the Application so the view can be built against it.
    def run(lines: 1, tick_interval: 40, theme: nil, out: $stdout)
      app = Application.new(mode: :inline, lines: lines, theme: theme, out: out)
      app.tick_interval = tick_interval
      view = yield(app)
      app.run(view)
      view
    end

    # Print one styled line. `color` is a Theme palette name (:info, :success,
    # :error, :warning, :dim, …); unknown names fall back to :normal.
    def say(text, color = :normal, bold: false, out: $stdout)
      if tty?(out)
        out.puts("#{Ansi.sgr(style_for(color, bold))}#{text}#{Ansi::RESET}")
      else
        out.puts(text)
      end
      nil
    end

    # Censor a word — a potty mouth ought to know how. Keeps the first and
    # last letter, stars the middle. (Purely for the laugh.)
    def bleep(word, char: '*')
      return word if word.length <= 2

      "#{word[0]}#{char * (word.length - 2)}#{word[-1]}"
    end

    def style_for(color, bold)
      c = Theme::PALETTE[color] || Theme::PALETTE[:normal]
      Style.new(fg: c[:fg], bg: c[:bg], bold: bold)
    end

    def tty?(out)
      out.respond_to?(:tty?) && out.tty?
    end
  end
end
