# Quick Start

Build your first v-gui application in 5 minutes.

## Prerequisites

- V installed ([vlang.io](https://vlang.io))
- Basic familiarity with V syntax

## Install v-gui

```bash
v install gui
```

## Create Your First App

Create a file `hello.v`:

```v
import gui

struct App_9 {
pub mut:
	clicks int
}

fn main() {
	mut window := gui.window(
		state:   &App_9{}
		width:   300
		height:  300
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[App_9]()
	return gui.column(
		width:   w
		height:  h
		h_align: .center
		v_align: .middle
		sizing:  gui.fixed_fixed
		content: [
			gui.text(text: 'Welcome to v-gui'),
			gui.button(
				content:  [gui.text(text: '${app.clicks} Clicks')]
				on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[App_9]()
					app.clicks += 1
				}
			),
		]
	)
}
```

## Run It

```bash
v run hello.v
```

You should see a window with centered text and a button that counts clicks.

## Understanding the Code

### The State

```oksyntax
struct App_9 {
pub mut:
	clicks int
}
```

Application state lives in a struct. v-gui stores this for you and makes it
available in views and event handlers.

### The Window

```oksyntax
mut window := gui.window(
	state:   &App_9{}
	width:   300
	height:  300
	on_init: fn (mut w gui.Window) {
		w.update_view(main_view)
	}
)
```

Create a window with initial dimensions and state. The `on_init` callback
runs once when the window is ready. Call `update_view()` to set the view
generator function.

### The View Generator

```oksyntax
fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[App_9]()
	return gui.column(...)
}
```

A view generator is a function that returns a `View`. v-gui calls this
function whenever the UI needs to update (user interaction, window resize).

Access state with `window.state[YourType]()`.

### The Layout

```oksyntax
return gui.column(
	width:   w
	height:  h
	h_align: .center
	v_align: .middle
	sizing:  gui.fixed_fixed
	content: [
		gui.text(text: 'Welcome to v-gui'),
		gui.button(...)
	]
)
```

A `column` stacks its children vertically. Size it to match the window,
center children horizontally and vertically.

### The Button

```oksyntax
gui.button(
	content:  [gui.text(text: '${app.clicks} Clicks')]
	on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
		mut app := w.state[App_9]()
		app.clicks += 1
	}
)
```

Buttons can contain other views. The `on_click` callback receives the
layout, event, and window. Get mutable state and update it. v-gui
automatically regenerates the view after the event completes.

## Key Concepts

### Immediate Mode

v-gui regenerates the entire view on every update. This sounds slow but is
actually very fast. The benefit: you never have to remember to undo
previous UI state. Just describe what the UI should look like for the
current state.

### Declarative Syntax

UI is described by nesting function calls. Layout is relative (flex-box
style) rather than absolute x,y positioning.

### Thread Safety

You can call `window.update_view()` from any thread. v-gui handles
synchronization.

## Next Steps

- **[Core Concepts](core/views.md)** - Understand views, layout, and sizing
- **[Components](components/README.md)** - Explore available UI components
- **[Examples](examples/)** - See more complete applications
- **[Guides](guides/)** - Learn specific techniques

## Common Patterns

### Multiple Views

Switch between different views by calling `update_view()` with different
view generators:

```oksyntax
// In an event handler
w.update_view(settings_view)
```

### Nested Layouts

Combine rows and columns:

```oksyntax
gui.column(
	content: [
		gui.row(content: [
			gui.text(text: 'Name:'),
			gui.input(...),
		]),
		gui.row(content: [
			gui.text(text: 'Email:'),
			gui.input(...),
		]),
	]
)
```

### Theming

Apply a different theme:

```oksyntax
window.set_theme(gui.theme_light)
```

See [Themes](core/themes.md) for creating custom themes.
