# Dialogs and Panels

Overlays and expandable content.

## dialog

Modal dialog overlay.

### Basic Usage

```w
import gui

struct App_19 {
pub mut:
	show_dialog bool
}

fn view(window &gui.Window) gui.View {
	app := window.state[App_19]()
	return gui.column(
		content: [
			gui.button(
				content:  [gui.text(text: 'Show Dialog')]
				on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[App_19]()
					app.show_dialog = true
				}
			),
			if app.show_dialog {
				window.dialog(
					width:   400
					height:  200
					content: [gui.text(text: 'Dialog Content'),
						gui.button(
							content:  [gui.text(text: 'Close')]
							on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
								mut app := w.state[App_19]()
								app.show_dialog = false
							}
						)]
				)
			} else {
				gui.text(text: '')
			},
		]
	)
}
```

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `content` | `[]View` | Dialog contents |
| `width`, `height` | `f32` | Dialog dimensions |
| `title` | `string` | Dialog title |
| `closable` | `bool` | Show close button |
| `on_close` | `fn` | Close handler |

### With Title

```oksyntax
gui.dialog(
	title:   'Confirmation'
	content: [
		gui.text(text: 'Are you sure?'),
		gui.row(content: [
			gui.button(content: [gui.text(text: 'Yes')]),
			gui.button(content: [gui.text(text: 'No')]),
		]),
	]
)
```

## expand_panel

Collapsible panel with header.

### Basic Usage

```oksyntax
gui.expand_panel(
	title:    'Advanced Settings'
	expanded: show_advanced
	content:  [
		gui.text(text: 'Advanced setting 1'),
		gui.text(text: 'Advanced setting 2'),
	]
	on_toggle: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
		mut app := w.state[App_20]()
		app.show_advanced = !app.show_advanced
	}
)
```

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `title` | `string` | Panel header |
| `expanded` | `bool` | Expanded state |
| `content` | `[]View` | Panel contents |
| `on_toggle` | `fn` | Expand/collapse handler |

## tooltip

Hover hint overlay.

### Basic Usage

```oksyntax
gui.button(
	content: [gui.text(text: 'Save')]
	tooltip: 'Save document (Ctrl+S)'
)
```

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `text` | `string` | Tooltip text |
| `delay` | `int` | Show delay (ms) |

## Common Patterns

### Confirmation Dialog

```oksyntax
gui.dialog(
	title:   'Delete File'
	width:   350
	content: [
		gui.text(text: 'This action cannot be undone.'),
		gui.row(
			spacing: 10
			content: [
				gui.button(
					content: [gui.text(text: 'Delete')]
					style:   danger_style
				),
				gui.button(content: [gui.text(text: 'Cancel')]),
			]
		),
	]
)
```

### Settings Panel

```oksyntax
gui.column(
	content: [
		gui.expand_panel(
			title:    'Display'
			expanded: true
			content:  display_settings
		),
		gui.expand_panel(
			title:    'Privacy'
			expanded: false
			content:  privacy_settings
		),
	]
)
```

### Button with Tooltip

```oksyntax
gui.button(
	content: [
		gui.text(text: gui.icon_help, text_style: gui.theme().icon3)
	]
	tooltip: 'Get help'
)
```

## Related Topics

- **[State Management](../core/state-management.md)** - Dialog visibility
- **[Events](../core/events.md)** - Dialog handlers
- **[Containers](containers.md)** - Floating containers