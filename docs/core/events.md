# Events

v-gui provides event handling for mouse, keyboard, and window events.
Events are processed through callback functions passed to UI components.

## Event Types

### Mouse Events

- **Click**: Mouse button pressed and released
- **Mouse move**: Cursor position changed
- **Mouse down**: Mouse button pressed
- **Mouse up**: Mouse button released
- **Scroll**: Mouse wheel or trackpad scroll

### Keyboard Events

- **Key down**: Key pressed
- **Key up**: Key released
- **Character input**: Text character entered

### Window Events

- **Resize**: Window dimensions changed
- **Focus**: Window gained/lost focus
- **Close**: Window close requested

## Event Callbacks

Components accept event handler functions with this signature:

```oksyntax
fn (layout &Layout, mut event Event, mut window Window)
```

Parameters:
- `layout` - Component's layout (position, size, shape)
- `event` - Event details (mutable for event propagation control)
- `window` - Window reference for state access

## Common Event Handlers

### on_click

Triggered when a button or interactive element is clicked:

```v
import gui

gui.button(
	content:  [gui.text(text: 'Click Me')]
	on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
		println('Button clicked!')
	}
)
```

### on_char

Triggered when text is entered (used by input components):

```oksyntax
gui.input(
	on_char: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
		// Handle character input
		char_code := e.char_code
		println('Character entered: ${rune(char_code)}')
	}
)
```

### on_key_down

Triggered when a key is pressed:

```oksyntax
on_key_down: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
	match e.key {
		.enter {
			println('Enter pressed')
		}
		.escape {
			println('Escape pressed')
		}
		else {}
	}
}
```

## Accessing State in Event Handlers

Get read-only state:

```oksyntax
on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
	app := w.state[App]()  // Read-only access
	println('Current count: ${app.counter}')
}
```

Get mutable state:

```oksyntax
import gui

struct App {
pub mut:
	counter int
}

// ...

on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
	mut app := w.state[App]()  // Mutable access
	app.counter += 1
	// v-gui automatically regenerates view after event completes
}
```

## View Regeneration

After modifying state in an event handler, v-gui automatically calls your
view generator to create an updated view. You don't need to manually
trigger a redraw.

```v
import gui

struct App {
pub mut:
	text string
}

fn view(window &gui.Window) gui.View {
	app := window.state[App]()
	return gui.column(
		content: [
			gui.text(text: app.text), // Shows updated text
			gui.button(
				content:  [gui.text(text: 'Change Text')]
				on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[App]()
					app.text = 'Updated!'
					// View automatically regenerates here
				}
			),
		]
	)
}
```

## Event Propagation

Events bubble up through the layout tree. Stop propagation with:

```oksyntax
on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
	e.stop_propagation = true  // Prevent parent from receiving event
	// Handle click
}
```

## Mouse Position

Get mouse coordinates from events:

```oksyntax
on_click: fn (layout &gui.Layout, mut e gui.Event, mut w gui.Window) {
	x := e.mouse_x
	y := e.mouse_y
	println('Clicked at: ${x}, ${y}')
}
```

Coordinates are in logical pixels relative to the window.

## Keyboard Modifiers

Check modifier keys in events:

```oksyntax
on_key_down: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
	if e.modifiers.ctrl {
		println('Ctrl key held')
	}
	if e.modifiers.shift {
		println('Shift key held')
	}
	if e.modifiers.alt {
		println('Alt key held')
	}
	if e.modifiers.cmd {
		println('Cmd/Super key held')
	}
}
```

## Window Events

Handle window resize:

```oksyntax
fn main() {
	mut window := gui.window(
		// ...
		on_resize: fn (mut w gui.Window) {
			println('Window resized')
			// View regenerates automatically with new size
		}
	)
	window.run()
}
```

v-gui automatically regenerates the view on resize, so you typically don't
need an `on_resize` handler unless you have custom logic.

## Common Patterns

### Increment Counter

```v
import gui

struct App {
pub mut:
	count int
}

fn view(window &gui.Window) gui.View {
	app := window.state[App]()
	return gui.button(
		content:  [gui.text(text: '${app.count}')]
		on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
			mut app := w.state[App]()
			app.count += 1
		}
	)
}
```

### Toggle Boolean

```v
import gui

struct App {
pub mut:
	enabled bool
}

fn view(window &gui.Window) gui.View {
	app := window.state[App]()
	return gui.toggle(
		select:   app.enabled
		on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
			mut app := w.state[App]()
			app.enabled = !app.enabled
		}
	)
}
```

### Form Submission

```oksyntax
import gui

struct App {
pub mut:
	name  string
	email string
}

fn form_view(window &gui.Window) gui.View {
	return gui.column(
		content: [
			gui.input(
				on_text_changed: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[App]()
					app.name = e.text
				}
			),
			gui.button(
				content:  [gui.text(text: 'Submit')]
				on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
					app := w.state[App]()
					submit_form(app.name, app.email)
				}
			),
		]
	)
}

fn submit_form(name string, email string) {
	println('Submitted: ${name}, ${email}')
}
```

### Escape to Close Dialog

```oksyntax
gui.dialog(
	on_key_down: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
		if e.key == .escape {
			mut app := w.state[App]()
			app.show_dialog = false
		}
	}
	content: [...]
)
```

## Thread Safety

You can call `window.update_view()` from any thread to switch views or
trigger regeneration:

```oksyntax
spawn fn (mut w gui.Window) {
	// Background task
	result := do_work()
	
	// Update UI from background thread
	w.update_view(results_view)
}(mut window)
```

v-gui handles synchronization internally.

## Related Topics

- **[State Management](state-management.md)** - Managing application state
- **[Components](../components/README.md)** - Component-specific events
- **[Focus Management](../guides/focus-management.md)** - Keyboard
  navigation