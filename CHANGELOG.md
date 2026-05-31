# Changelog

All notable changes to potty are documented here. The format is loosely based
on [Keep a Changelog](https://keepachangelog.com/), and the project follows
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- **Styleable focus chrome (`FocusStyle`)** — potty's `:focus` stylesheet rule.
  A pure-data, surface-agnostic decoration spec (sibling to `Style`) that says
  how a focusable widget shows focus and whether it carries a border, with
  composable knobs: `border`/`focus_border` (box that recolors on focus —
  `.boxed` keeps the same weight by default, `focus: :heavy` to thicken too),
  `marker` (left-gutter indicator), `fill` (focused-field background), plus the
  colours for each. Resolved per widget against the `Theme` (the global look)
  or a per-widget `focus_style=` override — the CSS model: focus is a property
  of the element, not a wrapper (`Panel`/`VBox` remain the way to *group*).
  Presets: `FocusStyle.boxed` / `.gutter` / `.filled` / `.none`. Geometry is
  reserved from the static config, never from focus state, so focusing never
  reflows the layout. Chrome applies to focusable widgets only (a global boxed
  style won't box a `Label`). Default is `FocusStyle.none` — existing apps
  render unchanged; opt in via `Theme.new(palette, FocusStyle.boxed)` or
  `theme.focus_style = …`.
- **Hardware text cursor** — `Surface#place_cursor(row, col, shape:)` lets a
  widget request the real terminal cursor at a cell for one frame (cleared each
  `erase`, so a frame with no request hides it). `TextInput` uses it: a focused
  field now shows a genuine blinking caret instead of a faked reverse-video
  block. Shape (`:bar` / `:block` / `:underline`, default `:bar`) is honoured
  on `InlineSurface` via DECSCUSR; `CursesSurface` falls back to cursor
  visibility (curses exposes no shape control). `TextInput.new(cursor_shape:)`
  picks the shape. Windows without `place_cursor` (e.g. test fakes) degrade
  silently.
- **Terminal resize handling** — `CursesSurface` reacts to `KEY_RESIZE`:
  `Application#resize` re-reads the screen dimensions (`Surface#handle_resize`)
  and re-lays-out the current view, so a full-screen curses app reflows on
  window resize. `InlineSurface#handle_resize` re-detects width and rebuilds the
  grid (not auto-driven — inline has no resize key; a host trapping SIGWINCH can
  call it).
- `CheckboxGroup#selected=` — replace the whole selection set programmatically
  (the hook for a "master" / select-all row driving its individual rows from
  outside, without reaching into internal state). Ignores unknown values and
  order/dupes; fires `:change` only when the set actually changes, so a
  master↔individuals wiring can't loop.
- **`TextBlock` widget** — static multi-line text from a `String` with newlines
  (height = line count). `wrap: false` renders verbatim (preformatted art /
  tables); `wrap: true` word-wraps to the rect width (prose, log tails, error
  messages). The block sibling of `Label`.
- **Modal `pop_view` results** — `push_view(view, on_result:)` + `pop_view(result)`:
  push a child, get a value back when it closes (callback fires in the pusher's
  context); a bare pop / ESC delivers `nil` (cancelled). No blocking.
- **`Application#schedule(after_seconds) { … }`** — run a block once after a
  delay on the tick clock; returns a `ScheduledTask` you can `cancel`. Clock
  starts on the first tick (robust to a late first frame), deterministic to
  test (`tick(now)` takes an explicit Time).

### Changed
- **Default focus look is now `FocusStyle.gutter`** (was effectively none) — a
  form shows where focus is out of the box (a left-gutter marker; chrome-light,
  adds no height, no reflow). Pass `FocusStyle.none` for the previous bare look,
  or `.boxed` / `.filled` for more. Affects any widget tree built on a default
  `Theme.new`.

### Fixed
- **Nil surface during `build_layout`** — `build_layout` now runs on a view's
  first `#activate` (once the Application has built the surface) instead of at
  construction, so reading `app.surface.size` / theme during layout no longer
  nils out. (A view test now calls `view.activate(app)` before asserting on its
  widgets.)
- **Ghost fragments after a view transition** — popping/pushing to a shorter
  view (or resizing) could leave stale cells on screen when the old view drew
  wide / multi-byte glyphs (block elements, box drawing), because ncurses'
  damage tracking doesn't always mark those cells dirty. `Surface#force_repaint!`
  arms a one-shot full repaint (curses uses `wclear` for that frame instead of
  `werase`); `Application` calls it on `push_view`/`pop_view`/`resume`/`resize`.
  Per-frame rendering still uses damage-tracked `erase`, so animation doesn't
  strobe. `InlineSurface` is unaffected (it rewrites every row each frame).

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
- Second demo: `potty_inline_demo` (TTY/inline) alongside `potty_demo` (curses).

### Changed
- **`Theme` is now pure data** (no curses) — `style`/`[]`/`attr` all return a
  `Style` (symbolic colours + attributes), resolved per surface. This is what
  lets every widget render in *either* mode (curses pair or ANSI SGR) with no
  per-widget special-casing. Code that drew straight to a curses window with
  `theme[:x]` must now draw via the surface (it resolves the Style).
- `View#spacing` is overridable; `Enter` advances focus like `Tab` when the
  focused widget doesn't consume it (form flow).
- Internal consolidation: `TextInput` and the list `InputItem` now share a
  `Potty::LineEditor`; dead `Layout.split_horizontal`/`fill` and the unused
  `WindowManager` sub-window API removed.

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
