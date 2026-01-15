# State Management

v-gui uses a simple, functional approach to state management. State lives
in a struct, views are pure functions of that state, and updates trigger
automatic view regeneration.

## The State Struct

Define application state in a struct:

```v
import gui

struct App {
pub mut:
	counter int
	text    string
	items   []string
}
```

All fields should be `pub mut` so they can be accessed and modified.

## Storing State in Window

Pass state to the window when creating it:

```v
import gui

fn main() {
	mut window := gui.window(
		state:   &App{
			counter: 0
			text:    ''
			items:   []
		}
		width:   400
		height:  300
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.run()
}
```

The window stores a reference to your state and makes it available
everywhere.

## Accessing State in Views

Views are pure functions that read state:

```v
import gui

fn main_view(window &gui.Window) gui.View {
	app := window.state[App]() // Get read-only state

	return gui.column(
		content: [
			gui.text(text: 'Counter: ${app.counter}'),
			gui.text(text: 'Text: ${app.text}'),
		]
	)
}
```

Use `window.state[YourType]()` to get typed access to your state.

## Modifying State in Event Handlers

Event handlers get mutable access to state:

```v
import gui

gui.button(
	content:  [gui.text(text: 'Increment')]
	on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
		mut app := w.state[App]() // Get mutable state
		app.counter += 1
		// View regenerates automatically after event handler completes
	}
)
```

After the event handler completes, v-gui automatically calls your view
generator with the updated state.

## Automatic View Regeneration

v-gui uses immediate mode rendering: views are regenerated when state
changes.

### In Event Handlers (Automatic)

When you modify state in an event handler, v-gui automatically regenerates
the view after the handler completes. This happens because the event
handling mechanism checks if the event was handled (via
`Event.is_handled`) and calls `update_view()` internally.

```
User clicks button
      ↓
Event handler runs
      ↓
State is modified
      ↓
Event handler completes
      ↓
Event system sees Event.is_handled = true
      ↓
Event system calls update_view() automatically
      ↓
View generator called
      ↓
New View created
      ↓
Layout calculated
      ↓
Screen redrawn
```

In event handlers, you don't need to call `update_view()` - just modify
state:

```v
import gui

gui.button(
	content:  [gui.text(text: 'Increment')]
	on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
		mut app := w.state[App]()
		app.counter += 1
		// View automatically regenerates after this function returns
	}
)
```

### In Background Threads (Manual)

When you modify state from a background thread, you **must** call
`update_view()` explicitly because there's no event handler to trigger
automatic regeneration:

```v
import gui
import time

spawn fn (mut w gui.Window) {
	time.sleep(2 * time.second)
	mut app := w.state[App]()
	app.status = 'Task complete'
	w.update_view(main_view) // Required: explicit regeneration
}(mut window)
```

### When to Call update_view()

Call `update_view()` explicitly when:
- Modifying state from background threads
- Switching between different view generators
- Programmatically triggering view changes outside event handlers

Don't call `update_view()` in event handlers - it happens automatically.

## Benefits of Immediate Mode

### No Synchronization Bugs

The view is always a function of the current state. No stale UI, no
out-of-sync state.

### No Manual Updates (Usually)

In event handlers, you don't remember which parts of the UI to update. The
entire view regenerates automatically.

### Predictable

Same state always produces the same view. Easy to test and reason about.

### Thread-Safe

Call `window.update_view()` from any thread. v-gui handles synchronization.

## State Patterns

### Simple Counter

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

### Form State

```v
import gui

struct App {
pub mut:
	name  string
	email string
	age   int
}

fn form_view(window &gui.Window) gui.View {
	app := window.state[App]()
	return gui.column(
		content: [
			gui.input(
				placeholder: 'Name'
				text:        app.name
				on_change:   fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[App]()
					app.name = e.text
				}
			),
			gui.input(
				placeholder: 'Email'
				text:        app.email
				on_change:   fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[App]()
					app.email = e.text
				}
			),
		]
	)
}
```

### List State

```v
import gui

struct App {
pub mut:
	items []string
	input string
}

fn list_view(window &gui.Window) gui.View {
	app := window.state[App]()
	return gui.column(
		content: [
			gui.row(content: [
				gui.input(
					text:      app.input
					on_change: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
						mut app := w.state[App]()
						app.input = e.text
					}
				),
				gui.button(
					content:  [gui.text(text: 'Add')]
					on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
						mut app := w.state[App]()
						if app.input != '' {
							app.items << app.input
							app.input = ''
						}
					}
				),
			]),
			...app.items.map(fn (item string) gui.View {
				return gui.text(text: item)
			}),
		]
	)
}
```

### View Switching

```v
import gui

enum ViewMode {
	home
	settings
	about
}

struct App {
pub mut:
	view_mode ViewMode
}

fn main_view(window &gui.Window) gui.View {
	app := window.state[App]()
	return gui.column(
		content: [
			// Navigation
			gui.row(
				content: [
					gui.button(
						content:  [gui.text(text: 'Home')]
						on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[App]()
							app.view_mode = .home
						}
					),
					gui.button(
						content:  [gui.text(text: 'Settings')]
						on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[App]()
							app.view_mode = .settings
						}
					),
				]
			),
			// Content
			match app.view_mode {
				.home { home_view(window) }
				.settings { settings_view(window) }
				.about { about_view(window) }
			},
		]
	)
}

fn home_view(window &gui.Window) gui.View {
	return gui.text(text: 'Home View')
}

fn settings_view(window &gui.Window) gui.View {
	return gui.text(text: 'Settings View')
}

fn about_view(window &gui.Window) gui.View {
	return gui.text(text: 'About View')
}
```

## Transient UI State

Some state doesn't belong in your application state:
- Which element has focus
- Scroll positions
- Text selection ranges

v-gui manages this automatically in `ViewState`. Components handle their
own transient state.

For scrolling, use `id_scroll`:

```oksyntax
gui.container(
	id_scroll: 1  // v-gui remembers scroll position for id 1
	content: [...]
)
```

## State Update Patterns

### Computed Properties

Use V's computed properties for derived state:

```v
import gui

struct App {
pub mut:
	first_name string
	last_name  string
}

pub fn (app App) full_name() string {
	return '${app.first_name} ${app.last_name}'
}

fn view(window &gui.Window) gui.View {
	app := window.state[App]()
	return gui.text(text: app.full_name())
}
```

### State Validation

Validate in event handlers before updating:

```oksyntax
on_change: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
	mut app := w.state[App]()
	if e.text.len <= 50 {  // Validate
		app.name = e.text
	}
}
```

### Async State Updates

Update state from background threads:

```v
import gui
import time

spawn fn (mut w gui.Window) {
	time.sleep(2 * time.second)
	mut app := w.state[App]()
	app.status = 'Task complete'
	w.update_view(main_view) // Trigger view regeneration
}(mut window)
```

## Performance Considerations

### View Regeneration is Fast

Layout calculation takes < 1ms for hundreds of elements. Don't worry about
regenerating the entire view.

### Minimize State

Keep only essential application state in your struct. Don't store derived
values.

**Bad**:
```oksyntax
struct App {
pub mut:
	items       []Item
	item_count  int  // Derived from items.len
}
```

**Good**:
```v
import gui

struct App {
pub mut:
	items []Item
}

pub fn (app App) item_count() int {
	return app.items.len
}
```

## Related Topics

- **[Events](events.md)** - Event handling and state modification
- **[Views](views.md)** - Pure view functions
- **[Architecture](../ARCHITECTURE.md)** - Immediate mode rendering