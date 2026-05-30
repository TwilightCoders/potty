# frozen_string_literal: true

require_relative 'style'
require_relative 'theme'
require_relative 'ansi'

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

    def style_for(color, bold)
      c = Theme::PALETTE[color] || Theme::PALETTE[:normal]
      Style.new(fg: c[:fg], bg: c[:bg], bold: bold)
    end

    def tty?(out)
      out.respond_to?(:tty?) && out.tty?
    end
  end
end
