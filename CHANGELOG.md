# Changelog

All notable changes to potty are documented here. The format is loosely based
on [Keep a Changelog](https://keepachangelog.com/), and the project follows
[Semantic Versioning](https://semver.org/).

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
