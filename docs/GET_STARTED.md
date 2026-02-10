# Getting Started with v-gui

Welcome! If you're here, you're about to discover one of the most enjoyable ways to build
desktop apps. v-gui combines the simplicity of V with a refreshingly straightforward approach
to UI development.

No boilerplate. No ceremony. Just describe what you want and watch it appear.

## Your First App in 30 Seconds

```v ignore
import gui

fn main() {
	mut window := gui.window(
		width: 300
		height: 200
		on_init: fn (mut w gui.Window) {
			w.update_view(fn (window &gui.Window) gui.View {
				return gui.text(text: 'Hello, v-gui!')
			})
		}
	)
	window.run()
}
```

That's a complete, runnable app. Run it with `v run hello.v` and you've got a window with text.

## The Big Idea

v-gui follows one simple principle: **your UI is just a function of your data**.

```
State  --->  View Function  --->  Screen
(data)       (you write)         (v-gui does)
```

When something changes—a button click, new data arrives, user types—v-gui calls your view
function again. You return what the UI should look like *now*. v-gui handles the rest.

No manual updates. No "set this label's text." No keeping track of what changed. Just return
the current view based on current state.

## A Real Example: Click Counter

Let's look at a proper app. Check out `examples/get_started.v` for the full code—here's the
essence:

```v ignore
// Your data
@[heap]
struct App {
pub mut:
	clicks int
}

// Your view function
fn main_view(window &gui.Window) gui.View {
	app := window.state[App]()

	return gui.column(
		h_align: .center
		v_align: .middle
		content: [
			gui.text(text: 'Welcome to GUI'),
			gui.button(
				content: [gui.text(text: '${app.clicks} Clicks')]
				on_click: fn (_, _, mut w gui.Window) {
					mut app := w.state[App]()
					app.clicks += 1
				}
			),
		]
	)
}
```

Click the button → `clicks` increases → v-gui calls `main_view` again → button shows new
count. The loop handles itself.

## Core Concepts

### State

Your app's data lives in a struct. Mark it `@[heap]` so it sticks around:

```v ignore
@[heap]
struct TodoApp {
pub mut:
	items         []string
	input_text    string
}
```

Access it in your view with `window.state[TodoApp]()`. Mutate it in event handlers with
`window.state[TodoApp]()` (yes, same call—V handles the mutability).

### Layouts: Rows and Columns

v-gui uses rows and columns for layout. Nest them to build any structure:

```v ignore
gui.column(content: [          // Vertical stack
	gui.row(content: [         // Horizontal stack inside
		gui.text(text: 'Left'),
		gui.text(text: 'Right'),
	]),
	gui.text(text: 'Below'),
])
```

```
┌─────────────────────────┐
│  ┌──────┐  ┌───────┐    │
│  │ Left │  │ Right │    │  ← row
│  └──────┘  └───────┘    │
├─────────────────────────┤
│  ┌───────────────────┐  │
│  │       Below       │  │  ← text
│  └───────────────────┘  │
└─────────────────────────┘
            ↑
         column
```

### Sizing: Fit, Fill, Fixed

Every widget can size itself three ways per axis:

| Mode    | Behavior                        |
|---------|---------------------------------|
| `fit`   | Shrink to content               |
| `fill`  | Expand to available space       |
| `fixed` | Use exact pixel value           |

Combine them: `sizing: gui.fit_fill` means fit width, fill height.

### Alignment

Center things easily:

```v ignore
gui.column(
	h_align: .center   // Horizontal: .left, .center, .right
	v_align: .middle   // Vertical: .top, .middle, .bottom
	content: [
		gui.text(text: 'Centered!')
	]
)
```

### Themes

Switch looks instantly:

```v ignore
window.set_theme(gui.theme_dark)           // Clean dark
window.set_theme(gui.theme_light)          // Clean light
window.set_theme(gui.theme_dark_bordered)  // Dark with borders
window.set_theme(gui.theme_gruvbox_dark)   // Retro vibes
window.set_theme(gui.theme_ocean_light)    // Calm blues
```

Or build your own with the theme designer (`examples/theme_designer.v`).

## Widgets at a Glance

v-gui comes with everything you need:

| Category    | Widgets                                              |
|-------------|------------------------------------------------------|
| Text        | `text`, `input`, `textarea`                          |
| Buttons     | `button`, `toggle`, `switch`, `checkbox`, `radio`    |
| Selection   | `select`, `dropdown`, `listbox`                      |
| Data        | `table`, `tree`, `markdown`                          |
| Graphics    | `image`, `svg`                                       |
| Layout      | `row`, `column`, `container`, `scroll`, `canvas`     |
| Feedback    | `progress_bar`, `pulsar`, `tooltip`, `dialog`        |
| Navigation  | `menu`, `menubar`, `tabs`                            |

All follow the same pattern: call the function, set some options, done.

## Native File Dialogs

Use native desktop file dialogs from `Window`:
- `native_open_dialog`
- `native_save_dialog`
- `native_folder_dialog`

On Linux/macOS, native dialogs are supported.
On other platforms, callbacks still fire and return `.error` with
`error_code == 'unsupported'`.

## Masked Input

`gui.input` supports masked input formatting and paste sanitization.

Fields:
- `mask string`
- `mask_preset InputMaskPreset = .none`
- `mask_tokens []MaskTokenDef`

Rules:
- `mask` wins when non-empty.
- `mask_preset` is used when `mask` is empty.
- `mask_tokens` adds or overrides token defs used by `mask`.

```v ignore
gui.input(
	id_focus:    1
	text:        app.phone
	mask_preset: .phone_us
	placeholder: '(555) 123-4567'
	on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
		w.state[App]().phone = s
	}
)
```

Custom token example:

```v ignore
gui.input(
	id_focus:    2
	text:        app.license
	mask:        'AA-9999'
	mask_tokens: [
		gui.MaskTokenDef{
			symbol:    `A`
			matcher:   is_ascii_letter
			transform: to_upper_ascii
		},
	]
	on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
		w.state[App]().license = s
	}
)
```

## Why v-gui Feels Different

**No widget objects to manage.** Traditional frameworks make you create button objects, store
references, call methods on them later. v-gui? Just return what you want. Every time.

**No data binding.** Other frameworks need you to wire data to UI elements. Here, you read
state and return views. That's the binding.

**No threading headaches.** Change state from anywhere. v-gui runs the view function at the
right time, on the right thread.

**Fast enough to not think about.** Layout runs in microseconds. Thousands of elements?
No problem. Regenerate the whole UI sixty times per second if you want.

## Running the Examples

The `examples/` folder is full of working apps demonstrating every feature:

```bash
# The basics
v run examples/get_started.v

# See all widgets
v run examples/buttons.v
v run examples/inputs.v
v run examples/containers.v

# Cool stuff
v run examples/animations.v     # Tweens, springs, hero transitions
v run examples/svg_demo.v       # Vector icon rendering
v run examples/tiger.v          # Complex SVG (Ghostscript Tiger)
v run examples/markdown.v       # Markdown rendering
v run examples/dialogs.v        # Custom + native dialogs
v run examples/text_transform.v # Rotated and affine text
v run examples/table_demo.v     # Table widget demo
v run examples/theme_designer.v
v run examples/snake.v          # Yes, it's a game
```

Read the code. It's short. That's the point.

## Next Steps

- **[`examples/get_started.v`](../examples/get_started.v)** - Fully commented starter app
- **[`ARCHITECTURE.md`](ARCHITECTURE.md)** - How v-gui works under the hood
- **[`LAYOUT_ALGORITHM.md`](LAYOUT_ALGORITHM.md)** - Deep dive into sizing and positioning
- **[`ANIMATIONS.md`](ANIMATIONS.md)** - Bring your UI to life
- **[`MARKDOWN.md`](MARKDOWN.md)** - Markdown rendering
- **[`TABLES.md`](TABLES.md)** - Table widget and data display

---

That's it. You now know enough to build real apps. The best way to learn more is to open an
example, change something, and see what happens. v-gui gets out of your way so you can focus
on what matters: making something useful.

Happy building!
