# Buttons and Toggles

Interactive controls for actions and boolean state.

## button

Clickable button for actions.

### Basic Usage

```v
import gui

gui.button(
	content:  [gui.text(text: 'Click Me')]
	on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
		println('Button clicked!')
	}
)
```

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `content` | `[]View` | Button contents (text, icons, etc.) |
| `on_click` | `fn` | Click handler |
| `disabled` | `bool` | Disable interaction |
| `style` | `ButtonStyle` | Visual styling |

### Button with Icon

```v
import gui

gui.button(
	content:  [
		gui.text(text: gui.icon_save, text_style: gui.theme().icon3),
		gui.text(text: 'Save'),
	]
	on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
		save_document()
	}
)
```

### Disabled Button

```oksyntax
gui.button(
	content:  [gui.text(text: 'Disabled')]
	disabled: true
	on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
		// This won't be called
	}
)
```

### Styled Buttons

**Primary button:**
```v
import gui

gui.button(
	content: [gui.text(text: 'Save')]
	style:   gui.ButtonStyle{
		...gui.theme().button_style
		color_background: gui.rgb(0, 120, 255)
		color:            gui.rgb(255, 255, 255)
	}
)
```

**Danger button:**
```v
import gui

gui.button(
	content: [gui.text(text: 'Delete')]
	style:   gui.ButtonStyle{
		...gui.theme().button_style
		color_background: gui.rgb(255, 59, 48)
		color:            gui.rgb(255, 255, 255)
	}
)
```

## toggle

On/off switch control.

### Basic Usage

```v
import gui

struct App {
pub mut:
	notifications_enabled bool
}

fn view(window &gui.Window) gui.View {
	app := window.state[App]()
	return gui.toggle(
		select:   app.notifications_enabled
		on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
			mut app := w.state[App]()
			app.notifications_enabled = !app.notifications_enabled
		}
	)
}
```

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `select` | `bool` | On/off state |
| `label` | `string` | Label text |  
| `on_click` | `fn` | Toggle handler |
| `disabled` | `bool` | Disable interaction |

### Toggle with Label

```oksyntax
gui.toggle(
	label:    'Enable notifications'
	select:   enabled
	on_click: handle_toggle
)
```

## switch

Toggle switch variant with sliding animation.

### Basic Usage

```oksyntax
gui.switch(
	select:   dark_mode
	on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
		mut app := w.state[App]()
		app.dark_mode = !app.dark_mode
	}
)
```

### Key Properties

Same as toggle, with visual styling differences.

## radio

Single selection from options.

### Basic Usage

```v
import gui

struct App {
pub mut:
	size string = 'Medium'
}

fn view(window &gui.Window) gui.View {
	app := window.state[App]()
	return gui.column(
		content: [
			gui.radio(
				label:    'Small'
				select:   app.size == 'Small'
				on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[App]()
					app.size = 'Small'
				}
			),
			gui.radio(
				label:    'Medium'
				select:   app.size == 'Medium'
				on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[App]()
					app.size = 'Medium'
				}
			),
			gui.radio(
				label:    'Large'
				select:   app.size == 'Large'
				on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[App]()
					app.size = 'Large'
				}
			),
		]
	)
}
```

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `label` | `string` | Option label |
| `select` | `bool` | Selected state |
| `on_click` | `fn` | Selection handler |

## radio_button_group

Grouped radio buttons with automatic exclusivity.

### Basic Usage

```oksyntax
gui.radio_button_group(
	options:   ['Option A', 'Option B', 'Option C']
	selected:  selected_option
	on_change: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
		mut app := w.state[App]()
		app.selected_option = e.selected
	}
)
```

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `options` | `[]string` | Available options |
| `selected` | `string` | Currently selected option |
| `on_change` | `fn` | Selection change handler |

## Common Patterns

### Button Row

```v
import gui

gui.row(
	spacing: 10
	content: [
		gui.button(content: [gui.text(text: 'OK')]),
		gui.button(content: [gui.text(text: 'Cancel')]),
	]
)
```

### Toolbar Buttons

```v
import gui

gui.row(
	spacing: 5
	content: [
		gui.button(content: [gui.text(text: gui.icon_save, text_style: gui.theme().icon3)]),
		gui.button(content: [gui.text(text: gui.icon_copy, text_style: gui.theme().icon3)]),
		gui.button(content: [gui.text(text: gui.icon_trash, text_style: gui.theme().icon3)]),
	]
)
```

### Settings Toggle List

```v
import gui

struct App {
pub mut:
	dark_mode     bool
	notifications bool
	auto_save     bool
}

fn settings_view(window &gui.Window) gui.View {
	app := window.state[App]()
	return gui.column(
		spacing: 15
		content: [
			gui.toggle(
				label:    'Dark Mode'
				select:   app.dark_mode
				on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[App]()
					app.dark_mode = !app.dark_mode
				}
			),
			gui.toggle(
				label:    'Notifications'
				select:   app.notifications
				on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[App]()
					app.notifications = !app.notifications
				}
			),
			gui.toggle(
				label:    'Auto-save'
				select:   app.auto_save
				on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[App]()
					app.auto_save = !app.auto_save
				}
			),
		]
	)
}
```

### Confirmation Dialog

```oksyntax
gui.column(
	content: [
		gui.text(text: 'Are you sure?'),
		gui.row(
			spacing: 10
			content: [
				gui.button(
					content: [gui.text(text: 'Yes')]
					style:   primary_button_style
				),
				gui.button(
					content: [gui.text(text: 'No')]
				),
			]
		),
	]
)
```

### Icon-Only Buttons

```oksyntax
gui.button(
	content: [
		gui.text(text: gui.icon_settings, text_style: gui.theme().icon3)
	]
	width:  40
	height: 40
)
```

## Related Topics

- **[Events](../core/events.md)** - Click event handling
- **[Styles](../core/styles.md)** - Button styling
- **[State Management](../core/state-management.md)** - Toggle state