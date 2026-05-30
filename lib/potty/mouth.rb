# frozen_string_literal: true

require_relative 'style'
require_relative 'theme'
require_relative 'ansi'

module Potty
  # The quick-and-dirty way to talk to a terminal — styled one-liners without
  # standing up a whole Application/View. The potty mouth runs its mouth at
  # your tty.
  #
  #   Potty::Mouth.say("deploying…", :info)
  #   Potty::Mouth.say("done", :success)
  #
  # Colour is dropped automatically when output isn't a TTY (piped/redirected),
  # so logs stay clean.
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
