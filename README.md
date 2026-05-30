# cursed

A curses-based terminal UI framework for Ruby. Build full-screen TUIs from a
tree of composable widgets, with view-stack navigation, a focus model, theming,
and frame-based animation.

```
┌─────────────────────────────────┐
│ → Say hello                     │
│   Configure                     │
│   Quit                          │
└─────────────────────────────────┘
 ↑↓: Navigate         HELLO         ESC: Quit
```

> **Status:** pre-release (`0.1.0`). The API is young and evolving under real
> consumers. Expect additive change.

## Installation

Requires the `curses` gem (a native extension) and a real terminal. Not yet
published to RubyGems — depend on it via git or a local path:

```ruby
# Gemfile
gem 'cursed', github: 'TwilightCoders/cursed'
# or, for local development:
gem 'cursed', path: '../cursed'
```

```ruby
require 'cursed'
```

## Quick start

A `Cursed::Application` runs a stack of `Cursed::View`s. A view builds a tree of
widgets in `build_layout` and reacts to input. Subclass `View`, hand the app a
root view, and call `run`:

```ruby
require 'cursed'

class HelloView < Cursed::View
  def build_layout
    @flash = Cursed::Widgets::FlashMessage.new(app)

    @list = Cursed::Widgets::List.new(app)
    @list.items = [
      Cursed::Widgets::ActionItem.new('Say hello') { flash_success('Hello!') },
      Cursed::Widgets::ActionItem.new('Quit')      { app.quit }
    ]

    @status = Cursed::Widgets::StatusBar.new(app)
    @status.left_text   = '↑↓: Navigate'
    @status.center_text = 'HELLO'
    @status.right_text  = 'ESC: Quit'

    @widgets = [@flash, @list, @status]
    @list.focus
  end

  def handle_escape
    app.quit
    true
  end
end

app = Cursed::Application.new
app.run(HelloView.new(app))
```

See [`examples/test_view.rb`](examples/test_view.rb) for a fuller demo
(`ruby examples/test_view.rb`).

## Core concepts

### Application

`Cursed::Application` owns the curses lifecycle and the event loop.

- `run(root_view)` — set up curses, push the root view, loop until `quit`.
- `push_view(view)` / `pop_view` — navigate a stack of views (e.g. drilling
  into a submenu and back). ESC pops by default unless the view's
  `handle_escape` consumes it.
- `quit` — stop the loop.
- `suspend` / `resume` — tear down and rebuild curses so you can shell out to an
  external process (an editor, a pager) and come back cleanly.
- `tick_interval=` — see [Animation & ticking](#animation--ticking).

### View

Subclass `Cursed::View` and override:

- `build_layout` — construct widgets into `@widgets` and call `focus` on the
  initial one. Called once at construction.
- `handle_escape` — return `true` to consume ESC (e.g. `app.quit` or a confirm),
  `false` to let the app pop the view.
- optionally `on_activate` / `on_deactivate` — run when the view becomes
  (in)active on the stack; a good place to rebuild dynamic lists.

The view routes keys to the focused widget first, then cycles focus with
**Tab / Shift+Tab** across widgets whose `can_focus?` is true. `flash_success`,
`flash_error`, and `flash_info` post messages to a `FlashMessage` widget in the
tree. Widgets are laid out top-to-bottom by [`Layout`](#layout).

### Widgets

Every widget inherits `Cursed::Widgets::Base` and implements as much of this
contract as it needs:

| Method | Purpose |
| --- | --- |
| `preferred_height(width)` | rows the widget wants (drives stack layout) |
| `layout(rect)` / `on_layout` | receive assigned position+size |
| `render(window)` | draw onto the curses window |
| `handle_key(ch)` | handle input; return `true` if consumed |
| `tick(now)` | per-frame update (time-driven widgets only) |
| `can_focus?` / `focus` / `blur` | focus participation |
| `show` / `hide` | visibility |

#### Widget catalog

- **`List`** — scrollable list of heterogeneous `ListItem`s. Delegates unhandled
  keys to the selected item (how `InputItem` captures typing). Item types:
  `ActionItem` (callback on Enter), `DisabledItem` / `SeparatorItem` (skipped by
  selection), `InputItem` (inline editable row), and `ColoredFieldsItem`
  (multi-color segments via `render_custom`).
- **`Label`** — static, non-focusable single-line text. `text:`, `color:`,
  `bold:`.
- **`TextInput`** — single-line editable field. Block cursor when focused, dim
  placeholder, horizontal scroll. `text` / `text=`, `placeholder`,
  `max_length`, `on_change` (gets a snapshot). ASCII input.
- **`Toggle`** — boolean `[●]`/`[○]`; Space/Enter flips. `value` / `value=`,
  `label`, `on_change`.
- **`RadioGroup`** — N mutually exclusive `{value, label}` options; arrows move a
  cursor, Space/Enter commits. `selected` / `selected=`, `on_change`.
- **`Countdown`** — passive display counting down N seconds, fires `on_expire`.
  Tick-driven (see below).
- **`FlashMessage`** — transient success/error/warning/info banner with timeout.
- **`StatusBar`** — bottom bar with `left_text` / `center_text` / `right_text`.
- **`ProgressBar`** — pure-string bar using Unicode eighth-blocks for sub-cell
  resolution; `render(0.0..1.0)` returns a string (usable on a curses window or
  plain stdout).

### Layout

`Cursed::Layout` is pure geometry over a `Rect(x, y, width, height)`:

- `Layout.stack(container, widgets, spacing:)` — vertical stack (the default a
  view uses), querying each widget's `preferred_height`.
- `Layout.split_horizontal(container, ratio:)` — left/right split.
- `Layout.fill(container)` — full container.

### Theme

`Cursed::Theme` maps semantic names to curses color pairs: `:normal`,
`:selected`, `:disabled`, `:success`, `:error`, `:warning`, `:info`, `:dim`,
`:header`, `:status`.

```ruby
theme[:error]                       # color-pair attr
theme.attr(:selected, bold: true)   # attr with A_BOLD / A_UNDERLINE OR'd in
```

## Animation & ticking

The event loop normally blocks on input. To drive animations and countdowns,
give the app a tick interval — the loop then wakes every N milliseconds, fans a
single shared `Time.now` out to every widget's `tick(now)`, and repaints.

```ruby
app = Cursed::Application.new
app.tick_interval = 40   # ms; ≈25fps. nil (default) = blocking, input-only.
app.run(view)
```

`Cursed::Sprite` is a named sequence of multiline-string frames; `Cursed::Animator`
is a widget that plays sprites by elapsed-time / fps, with `:loop` and `:once`
modes (`:once` fires `on_complete`).

```ruby
class LoaderView < Cursed::View
  def build_layout
    @spinner = Cursed::Animator.new(app, centered: true, color: :info)
    @spinner << Cursed::Sprites::Sample.spinner   # first sprite auto-plays
    @label   = Cursed::Widgets::Label.new(app, text: 'Loading…', color: :info)
    @widgets = [@spinner, @label]
  end
end

app = Cursed::Application.new
app.tick_interval = 40
app.run(LoaderView.new(app))
```

`add_sprite` (`<<`) registers more sprites; `play(:name)` swaps and restarts.
Define your own `Sprite.new(:name, frames: [...], fps:, mode:)`;
`Cursed::Sprites::Sample` (`spinner`, `plane`) is a template to copy.

## Development

```bash
bundle install
bundle exec rspec                       # full suite
bundle exec rspec spec/cursed/animator_spec.rb:42   # a single example
ruby examples/test_view.rb              # interactive demo (needs a real TTY)
```

Tests cover the pure-logic surface — input handling, frame timing (via an
injected clock), layout, rendering assertions through fake windows — so the
suite runs without `init_screen` or a real terminal.

## License

MIT.
