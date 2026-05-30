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

For a guided tour of the whole widget set, run the bundled demo in a real
terminal:

```bash
bin/cursed_demo     # from a checkout
cursed_demo         # when the gem is installed
```

It walks through forms (wired with events), motion (animation + spinners +
countdown), and layout (panels & columns). See
[`examples/test_view.rb`](examples/test_view.rb) for a smaller example.

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
**Tab / Shift+Tab** across widgets whose `can_focus?` is true (recursing into
containers). `flash_success`, `flash_error`, and `flash_info` post messages to a
`FlashMessage` widget in the tree. Widgets are laid out top-to-bottom by
[`Layout`](#layout), unless you nest them in [containers](#containers--composition).

### Events

Every widget mixes in `Cursed::Events`, so you can wire a UI together
declaratively instead of subclassing for one-off behavior. Widgets emit semantic
events; subscribe with `on`:

```ruby
name.on(:change)   { |text| greeting.text = "Hello, #{text}" }
notify.on(:change) { |on|   features.visible = on }
save.on(:press)    { app.pop_view }
```

Emitted events: `:focus`/`:blur` (any widget), `:change` (`TextInput`, `Toggle`,
`RadioGroup`, `CheckboxGroup`), `:select`/`:activate` (`List`), `:press`
(`Button`), `:expire` (`Countdown`), `:complete` (`Animator`, `Spinner`). `on`
returns self and supports multiple listeners. Keys are named in `Cursed::Keys`
(`ENTER`, `ESC`, `TAB`, `UP`, …) — no magic integers in your `handle_key`.

### Containers & composition

A `View`'s `@widgets` is laid out as a vertical stack, but any entry can be a
container holding more widgets — so you get nesting, columns, and framed panels.
Render, tick, and focus traversal all recurse.

- **`VBox`** / **`HBox`** — vertical stack / equal-width columns (`spacing:`).
- **`Panel`** — bordered, optionally titled container (`title:`, `style:`,
  `color:`) that insets its children.

```ruby
Cursed::Widgets::Panel.new(app, title: 'Settings').add(
  Cursed::Widgets::Label.new(app, text: 'Name'),
  Cursed::Widgets::TextInput.new(app),
  Cursed::Widgets::Button.new(app, label: 'Save')
)
```

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
- **`Button`** — focusable; Space/Enter emits `:press`. `on_press:` shortcut.
- **`TextInput`** — single-line editable field. Block cursor when focused, dim
  placeholder, horizontal scroll. `text` / `text=`, `placeholder`,
  `max_length`, emits `:change` (snapshot). ASCII input.
- **`Toggle`** — boolean `[●]`/`[○]`; Space/Enter flips. `value` / `value=`,
  `label`, emits `:change`.
- **`RadioGroup`** — N mutually exclusive `{value, label}` options; arrows move a
  cursor, Space/Enter commits. `selected` / `selected=`, emits `:change`.
- **`CheckboxGroup`** — multi-select sibling of `RadioGroup`; Space/Enter toggles
  the cursor row. `selected`, `selected?`, emits `:change` (selected values).
- **`Spinner`** — single-line activity indicator: animated braille glyph + live
  `label` + trailing state. `complete!(:success/:failure/:cancelled)` freezes the
  glyph and flips color (idempotent); emits `:complete`. Tick-driven.
- **`Countdown`** — passive display counting down N seconds, emits `:expire`.
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
