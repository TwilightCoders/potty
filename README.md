# potty

[![CI](https://github.com/TwilightCoders/potty/actions/workflows/ci.yml/badge.svg)](https://github.com/TwilightCoders/potty/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/potty.svg)](https://rubygems.org/gems/potty)

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

> **Status:** early release (`0.0.1`). The API is young and evolving under real
> consumers. Expect additive change.

## Installation

Requires the `curses` gem (a native extension) and a real terminal. Not yet
published to RubyGems — depend on it via git or a local path:

```ruby
# Gemfile
gem 'potty', github: 'TwilightCoders/potty'
# or, for local development:
gem 'potty', path: '../potty'
```

```ruby
require 'potty'
```

## Quick start

A `Potty::Application` runs a stack of `Potty::View`s. A view builds a tree of
widgets in `build_layout` and reacts to input. Subclass `View`, hand the app a
root view, and call `run`:

```ruby
require 'potty'

class HelloView < Potty::View
  def build_layout
    @flash = Potty::Widgets::FlashMessage.new(app)

    @list = Potty::Widgets::List.new(app)
    @list.items = [
      Potty::Widgets::ActionItem.new('Say hello') { flash_success('Hello!') },
      Potty::Widgets::ActionItem.new('Quit')      { app.quit }
    ]

    @status = Potty::Widgets::StatusBar.new(app)
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

app = Potty::Application.new
app.run(HelloView.new(app))
```

Two bundled demos, one per rendering mode — run either in a real terminal:

```bash
bin/potty_demo          # curses: full-screen
bin/potty_inline_demo   # inline: stays in the terminal flow
```

- **`potty_demo`** (curses) — a single self-demonstrating dashboard: one
  composed layout (it shows off the layout system by *being* it) whose form
  controls reconfigure the demo live — the Border radio restyles the very
  panels you're looking at, the Title field renames the header, the checkboxes
  show/hide the live animation.
- **`potty_inline_demo`** (inline/TTY) — styled output, a live in-place
  "deploy" (spinners resolving without a screen takeover), and interactive
  prompts (`ask`/`confirm`/`choose`) — all in your normal terminal flow.

See [`examples/test_view.rb`](examples/test_view.rb) for a smaller example.

## Core concepts

### Application

`Potty::Application` owns the curses lifecycle and the event loop.

- `run(root_view)` — set up curses, push the root view, loop until `quit`.
- `push_view(view, on_result:)` / `pop_view(result = nil)` — navigate a stack of
  views (e.g. drilling into a submenu and back). ESC pops by default unless the
  view's `handle_escape` consumes it. For modal flows, pass `on_result:` when
  pushing and `pop_view(value)` from the child — the pusher's callback fires
  with the value (a bare pop / ESC delivers `nil` = cancelled).
- `quit` — stop the loop.
- `suspend` / `resume` — tear down and rebuild curses so you can shell out to an
  external process (an editor, a pager) and come back cleanly.
- `schedule(after_seconds) { … }` — run a block once after a delay on the tick
  clock; returns a `ScheduledTask` you can `cancel`. Needs a `tick_interval`.
- `tick_interval=` — see [Animation & ticking](#animation--ticking).

### View

Subclass `Potty::View` and override:

- `build_layout` — construct widgets into `@widgets` and call `focus` on the
  initial one. Runs once, on the view's **first `activate`** (not at
  construction) — so the surface already exists and you can safely read
  `app.surface.size` here.
- `handle_escape` — return `true` to consume ESC (e.g. `app.quit` or a confirm),
  `false` to let the app pop the view. (ESC is routed here by the event loop,
  **not** through `handle_key` — a `when Keys::ESC` branch in `handle_key` is
  dead code.)
- optionally `on_activate` / `on_deactivate` — run when the view becomes
  (in)active on the stack; a good place to rebuild dynamic lists.

#### View lifecycle

```
View.new(app)                 # cheap; does NOT build the widget tree yet
  → app.push_view(view)
      → activate(app)
          → build_layout      # first activation only — surface now exists
          → on_activate
          → layout_widgets    # assigns each widget a rect from surface.size
      → render / tick / render / …   (the event loop)
  → app.pop_view              # → deactivate → on_deactivate
```

Swapping `@widgets` at runtime (e.g. a multi-step wizard in one view) is fine,
but call `layout_widgets` again afterward — newly added widgets have no `rect`
until you do, and `render` skips a widget without one.

The view routes keys to the focused widget first, then cycles focus with
**Tab / Shift+Tab** across widgets whose `can_focus?` is true (recursing into
containers). `flash_success`, `flash_error`, and `flash_info` post messages to a
`FlashMessage` widget in the tree. Widgets are laid out top-to-bottom by
[`Layout`](#layout), unless you nest them in [containers](#containers--composition).

### Events

Every widget mixes in `Potty::Events`, so you can wire a UI together
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
returns self and supports multiple listeners. Keys are named in `Potty::Keys`
(`ENTER`, `ESC`, `TAB`, `UP`, …) — no magic integers in your `handle_key`.

### Containers & composition

A `View`'s `@widgets` is laid out as a vertical stack, but any entry can be a
container holding more widgets — so you get nesting, columns, and framed panels.
Render, tick, and focus traversal all recurse.

- **`VBox`** / **`HBox`** — vertical stack / equal-width columns (`spacing:`).
- **`Panel`** — bordered, optionally titled container (`title:`, `style:`,
  `color:`) that insets its children.

```ruby
Potty::Widgets::Panel.new(app, title: 'Settings').add(
  Potty::Widgets::Label.new(app, text: 'Name'),
  Potty::Widgets::TextInput.new(app),
  Potty::Widgets::Button.new(app, label: 'Save')
)
```

### Widgets

Every widget inherits `Potty::Widgets::Base` and implements as much of this
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
- **`TextBlock`** — static multi-line text; hand it a `String` with newlines.
  `wrap: false` (default) renders verbatim, one source line per row (good for
  preformatted art / tables); `wrap: true` word-wraps to the rect width (good
  for prose, log tails, error messages). `text` / `text=`, `color:`.
- **`Button`** — focusable; Space/Enter emits `:press` (callback receives the
  button). `on_press:` shortcut.
- **`TextInput`** — single-line editable field. Shows a real hardware caret when
  focused (`cursor_shape: :bar`/`:block`/`:underline`), dim placeholder,
  horizontal scroll. `text` / `text=`, `placeholder`, `max_length`, emits
  `:change` (snapshot). ASCII input.
- **`Toggle`** — boolean `[●]`/`[○]`; Space/Enter flips. `value` / `value=`,
  `label`, emits `:change`.
- **`RadioGroup`** — N mutually exclusive `{value, label}` options; arrows move a
  cursor, Space/Enter commits. `selected` / `selected=`, emits `:change`.
- **`CheckboxGroup`** — multi-select sibling of `RadioGroup`; Space/Enter toggles
  the cursor row. `selected`, `selected?`, `selected=` (set the whole set — the
  hook for a "select all" master row), emits `:change` (selected values).
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

`Potty::Layout` is pure geometry over a `Rect(x, y, width, height)`:

- `Layout.stack(container, widgets, spacing:)` — vertical stack (the default a
  view uses), querying each widget's `preferred_height`. For columns / framed
  regions, nest [containers](#containers--composition) (`HBox` / `Panel`).

### Theme

`Potty::Theme` maps semantic names to a surface-agnostic `Style` (symbolic
colours + attributes) that each surface resolves to its own form (a curses
colour pair, or ANSI SGR). The canonical palette names, recognized across all
widgets:

| Name | Use |
| --- | --- |
| `:normal` | body text (terminal-default fg/bg — blends into any theme) |
| `:selected` | the focused/selected row highlight |
| `:dim` / `:disabled` | de-emphasized text, placeholders |
| `:success` `:error` `:warning` `:info` | semantic status colours |
| `:header` `:status` | header / status-bar bars (explicit bg) |

```ruby
theme.style(:error)                  # a Style (resolved per surface)
theme.style(:selected, bold: true)   # with bold/underline/reverse attrs
theme[:error]                        # alias for theme.style(:error)
```

Pass a partial palette to recolor: `Potty::Theme.new(info: { fg: :magenta, bg: :default })`.
Widgets take a `color:` (a palette name) where it makes sense, so a single
widget can override the semantic default.

### FocusStyle — the `:focus` stylesheet

How a focusable widget *shows* focus, and whether it carries a border, is a
styleable property — potty's equivalent of CSS `input:focus { … }`. It's set on
the `Theme` (the global look) or per widget (`widget.focus_style = …`), and it's
surface-agnostic like `Style`.

```ruby
theme.focus_style = Potty::FocusStyle.gutter   # ❯ marker in a left column (the default)
#                   Potty::FocusStyle.boxed     # box that recolors on focus (same weight; focus: :heavy to thicken)
#                   Potty::FocusStyle.filled    # focused field fills its background
#                   Potty::FocusStyle.none      # bare — no focus chrome
```

Composable knobs: `border` / `focus_border` (box style per state), `border_color`
/ `focus_color`, `marker` (left-gutter string on focus), `fill` / `fill_color`.
Geometry is reserved from the static config, never from focus state, so focusing
a widget never reflows the layout. Chrome applies to focusable widgets only (a
global boxed style won't box a `Label`). To *group* fields visually, use a
`Panel` / `VBox` — focus chrome is per-element, grouping is composition. The
default theme uses `FocusStyle.gutter` so a form shows where focus is out of the
box; pass `FocusStyle.none` for the bare look.

## Animation & ticking

The event loop normally blocks on input. To drive animations and countdowns,
give the app a tick interval — the loop then wakes every N milliseconds, fans a
single shared `Time.now` out to every widget's `tick(now)`, and repaints.

```ruby
app = Potty::Application.new
app.tick_interval = 40   # ms; ≈25fps. nil (default) = blocking, input-only.
app.run(view)
```

`Potty::Sprite` is a named sequence of multiline-string frames; `Potty::Animator`
is a widget that plays sprites by elapsed-time / fps, with `:loop` and `:once`
modes (`:once` fires `on_complete`).

```ruby
class LoaderView < Potty::View
  def build_layout
    @spinner = Potty::Animator.new(app, centered: true, color: :info)
    @spinner << Potty::Sprites::Sample.spinner   # first sprite auto-plays
    @label   = Potty::Widgets::Label.new(app, text: 'Loading…', color: :info)
    @widgets = [@spinner, @label]
  end
end

app = Potty::Application.new
app.tick_interval = 40
app.run(LoaderView.new(app))
```

`add_sprite` (`<<`) registers more sprites; `play(:name)` swaps and restarts.
Define your own `Sprite.new(:name, frames: [...], fps:, mode:)`;
`Potty::Sprites::Sample` (`spinner`, `plane`) is a template to copy.

## Rendering modes: curses vs inline

The same widget tree renders to either of two surfaces, chosen by
`Application.new(mode:)`:

```ruby
Potty::Application.new                              # :curses (default)
Potty::Application.new(mode: :inline, lines: 3, listen: true)
```

- **`:curses`** — full-screen. Takes over the terminal (`init_screen`, alternate
  screen), positions anywhere, reads input via `getch`. Pick this for an
  app/TUI that owns the screen: dashboards, menus, multi-view navigation,
  anything full-window or interactive across many widgets.
- **`:inline`** — draws an `lines:`-tall region **in place under the cursor**
  (like `docker compose` / `npm` progress), no alt-screen, terminal stays in
  cooked mode. Pick this to render *alongside* normal program output: progress,
  a spinner block, a quick prompt, a status region a CLI updates and then moves
  past. Pass `listen: true` to read input inline (raw mode, restored on exit).

Rule of thumb: **owns the whole screen → `:curses`; a region within a normal
terminal session → `:inline`.** `Potty::Mouth` (`say` / `ask` / `confirm` /
`choose`) is the batteries-included inline layer for one-off prompts.

## Development

```bash
bundle install
bundle exec rspec                       # full suite
bundle exec rspec spec/potty/animator_spec.rb:42   # a single example
ruby examples/test_view.rb              # interactive demo (needs a real TTY)
```

### Testing views without a terminal

potty is designed so you can unit-test views and widgets headlessly — no
`init_screen`, no TTY, fast suites. The pattern: drive `handle_key` / `tick` /
accessors the way the event loop would, and (for render assertions) pass a fake
window that records draw ops. Two small stand-ins are all you need:

```ruby
# A fake app: widgets only reach for app.theme and app.surface.
theme = Potty::Theme.new
app   = Object.new.tap { |a| a.define_singleton_method(:theme) { theme }
                             a.define_singleton_method(:surface) { @s ||= Object.new.tap { |s| def s.size = [24, 80] } } }

# A fake window: records setpos/addstr; attron just yields.
win = Object.new.tap do |w|
  w.instance_variable_set(:@ops, [])
  def w.ops = @ops
  def w.setpos(y, x) = @ops << [:setpos, y, x]
  def w.addstr(s)    = @ops << [:addstr, s]
  def w.attron(_a)   = (yield if block_given?)
end

input = Potty::Widgets::TextInput.new(app)
'hi'.each_char { |c| input.handle_key(c.ord) }
expect(input.text).to eq('hi')
```

For time-driven widgets and `Application#schedule`, pass an explicit `Time` to
`tick(now)` so timing is deterministic. `build_layout` runs on `activate`, so a
view test calls `view.activate(app)` before asserting on its widgets. The repo's
own `spec/` is full of this pattern if you want examples.

## License

MIT.
