# Changelog

All notable changes to potty are documented here. The format is loosely based
on [Keep a Changelog](https://keepachangelog.com/), and the project follows
[Semantic Versioning](https://semver.org/).

## [0.0.2] - 2026-05-30

### Added
- **Inline listen mode** — `InlineSurface` can now read input. With
  `Application.new(mode: :inline, listen: true)` it puts stdin in raw mode,
  decodes keys via `Potty::Input::Decoder`, and feeds the same event loop —
  so existing widgets are interactive *inline*, no full-screen takeover.
  Terminal restores to cooked on exit; Ctrl-C still quits.
- `Potty::Mouth` — batteries-included inline helpers built on
  `Application.new(mode: :inline)` (a convenience layer, not an Application
  facade):
  - `Mouth.say(text, color)` — styled line with no app; drops colour when
    output isn't a TTY so logs stay clean. (+ `Mouth.bleep`.)
  - `Mouth.ask(prompt)` → String, `Mouth.confirm(prompt)` → bool,
    `Mouth.choose(prompt, options)` → value — inline prompts (gum/fzf-style)
    composed from the existing widgets, returning a value.
- `Potty::Input::Decoder` — raw byte stream → `Keys` codes (CSI/SS3 escape
  sequences + bare-ESC timeout); the core that makes listen mode emit the
  same codes curses does, so widgets work unchanged in either mode.
- `Potty::Ansi` — the symbolic-colour → SGR mapping, shared by `InlineSurface`
  and `Mouth` (single source of truth).
- `RadioGroup#cursor_value` (the highlighted option, for one-shot choosers).
- `Application.new(out:, listen:, input:)` — redirect inline output, enable
  listening, and inject the input IO (testability/piping).

### CI
- GitHub Actions running the suite on Ruby 3.1–3.4.

## [0.0.1] - 2026-05-30

Initial public release. (Developed privately under the working name `cursed`,
which was already taken on RubyGems; renamed to `potty` for release.)

### Added
- **Application / View / Widget framework** — a view stack with push/pop
  navigation, focus cycling (Tab/Shift+Tab, recursing into containers), a tick
  loop for time-driven widgets, and suspend/resume.
- **Render-target Surface abstraction** — the same widget tree renders to a
  full-screen curses display (`:curses`, default) or an inline ANSI region
  redrawn in place under the cursor (`:inline`), via `Application.new(mode:)`.
- **Composition** — `Container`, `VBox`, `HBox`, and bordered `Panel`, with a
  shared `Border` helper (single/rounded/double/heavy).
- **Widgets** — `List` (+ `ActionItem`/`SeparatorItem`/`InputItem`/
  `ColoredFieldsItem`), `Label`, `Button`, `TextInput`, `Toggle`, `RadioGroup`,
  `CheckboxGroup`, `Spinner`, `Countdown`, `FlashMessage`, `StatusBar`,
  `ProgressBar`.
- **Animation** — `Sprite` + `Animator` (loop/once, fps, on_complete).
- **Events** — an `on`/`emit` mixin so widgets emit semantic events
  (`:change`, `:press`, `:select`, `:focus`, `:complete`, `:expire`).
- **Theming** — a semantic palette (`theme.style`) resolved per surface;
  transparent (terminal-default) backgrounds; injectable custom palette.
- **`Keys`** — named key codes with `getch` String/Integer normalization.
- A self-demonstrating `bin/potty_demo`.
