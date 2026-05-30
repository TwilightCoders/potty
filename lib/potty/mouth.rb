# frozen_string_literal: true

require_relative 'style'
require_relative 'theme'
require_relative 'ansi'
require_relative 'application'
require_relative 'view'
require_relative 'widgets/label'
require_relative 'widgets/text_input'
require_relative 'widgets/radio_group'

module Potty
  # potty's batteries-included inline helpers — quick terminal I/O that hides
  # the Application/View machinery and hands you back a value:
  #
  #   Potty::Mouth.say("deploying…", :info)        # styled output, no app
  #   name = Potty::Mouth.ask("Your name?")        # (with listen mode) -> String
  #   ok   = Potty::Mouth.confirm("Proceed?")      # -> true/false
  #
  # This is a convenience layer *built on* Application.new(mode: :inline), not
  # a second way to run views — to run your own inline View, use the inline
  # Application directly. Colour is dropped when output isn't a TTY, so logs
  # stay clean.
  module Mouth
    module_function

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

    # Ask for a line of text inline; returns the entered String, or nil if the
    # user cancels with ESC. Needs a TTY (listen mode).
    def ask(prompt, default: '', theme: nil, out: $stdout, input: $stdin)
      app = inline_app(lines: 2, theme: theme, out: out, input: input)
      app.run(view = Prompt::Ask.new(app, prompt: prompt, default: default))
      view.result
    end

    # Yes/no inline; returns true/false (ESC or Enter use `default`).
    def confirm(prompt, default: false, theme: nil, out: $stdout, input: $stdin)
      app = inline_app(lines: 1, theme: theme, out: out, input: input)
      app.run(view = Prompt::Confirm.new(app, prompt: prompt, default: default))
      view.result
    end

    # Pick one of `options` (values or {value:, label:}) inline; returns the
    # chosen value, or nil on ESC. Arrows move, Enter picks.
    def choose(prompt, options, theme: nil, out: $stdout, input: $stdin)
      app = inline_app(lines: options.size + 1, theme: theme, out: out, input: input)
      app.run(view = Prompt::Choose.new(app, prompt: prompt, options: options))
      view.result
    end

    # Build (not run) a configured inline, listening Application for a prompt.
    def inline_app(lines:, theme:, out:, input:)
      app = Application.new(mode: :inline, listen: true, lines: lines, theme: theme, out: out, input: input)
      app.tick_interval = 50
      app
    end

    def style_for(color, bold)
      c = Theme::PALETTE[color] || Theme::PALETTE[:normal]
      Style.new(fg: c[:fg], bg: c[:bg], bold: bold)
    end

    def tty?(out)
      out.respond_to?(:tty?) && out.tty?
    end

    # Small inline prompt views backing ask/confirm/choose. Each captures its
    # outcome in #result and quits the app when answered.
    module Prompt
      class Ask < Potty::View
        attr_reader :result

        def initialize(app, prompt:, default: '')
          @prompt = prompt
          @default = default
          @result = nil
          super(app)
        end

        def build_layout
          @field = Potty::Widgets::TextInput.new(app, text: @default)
          @widgets = [Potty::Widgets::Label.new(app, text: @prompt, color: :info), @field]
          @field.focus
        end

        def handle_key(ch)
          return true if super
          return false unless Potty::Keys.enter?(ch)

          @result = @field.text
          app.quit
          true
        end

        def handle_escape
          @result = nil
          app.quit
          true
        end
      end

      class Confirm < Potty::View
        attr_reader :result

        def initialize(app, prompt:, default: false)
          @prompt = prompt
          @default = default
          @result = nil
          super(app)
        end

        def build_layout
          hint = @default ? '[Y/n]' : '[y/N]'
          @widgets = [Potty::Widgets::Label.new(app, text: "#{@prompt} #{hint}", color: :info)]
        end

        def handle_key(ch)
          case ch
          when 'y'.ord, 'Y'.ord then finish(true)
          when 'n'.ord, 'N'.ord then finish(false)
          when *Potty::Keys::ENTERS then finish(@default)
          else false
          end
        end

        def handle_escape
          finish(@default)
        end

        private

        def finish(value)
          @result = value
          app.quit
          true
        end
      end

      class Choose < Potty::View
        attr_reader :result

        def initialize(app, prompt:, options:)
          @prompt = prompt
          @options = options
          @result = nil
          super(app)
        end

        def build_layout
          opts = @options.map { |o| o.is_a?(Hash) ? o : { value: o, label: o.to_s } }
          @radio = Potty::Widgets::RadioGroup.new(app, options: opts)
          @widgets = [Potty::Widgets::Label.new(app, text: @prompt, color: :info), @radio]
          @radio.focus
        end

        def handle_key(ch)
          if Potty::Keys.enter?(ch)
            @result = @radio.cursor_value
            app.quit
            return true
          end
          super # arrows move the radio cursor
        end

        def handle_escape
          @result = nil
          app.quit
          true
        end
      end
    end
  end
end
