# Focus Management

Control keyboard navigation and focus order.

## Focus Basics

Components can receive keyboard focus for navigation and input.

### Setting Focus Order

Use `id_focus` to control tab order:

```oksyntax
gui.column(
	content: [
		gui.input(id_focus: 1), // Tab order: 1st
		gui.input(id_focus: 2), // Tab order: 2nd
		gui.button(id_focus: 3, content: [gui.text(text: 'Submit')]), // Tab order: 3rd
	]
)
```

Lower `id_focus` values receive focus first.

### Skip Focus

Some components shouldn't receive focus:

```oksyntax
gui.text(
	text:       'Label (not focusable)'
	focus_skip: true
)
```

## Focus State

Check if a component has focus:

```oksyntax
on_key_down: fn (layout &gui.Layout, mut e gui.Event, mut w gui.Window) {
	if layout.has_focus {
		// Handle key input
	}
}
```

## Keyboard Navigation

Users navigate focus with:
- **Tab**: Next focusable element
- **Shift+Tab**: Previous focusable element
- **Arrow keys**: Directional navigation (in some components)

## Programmatic Focus

Set focus programmatically:

```oksyntax
w.set_focus(component_id)
```

## Focus Styling

Style focused components differently:

```v
import gui

gui.button(
	id_focus: 1
	style:    gui.ButtonStyle{
		...gui.theme().button_style
		color_focus: gui.rgb(110, 140, 220) // Highlight when focused
	}
	content:  [gui.text(text: 'Focusable Button')]
)
```

## Common Patterns

### Auto-Focus First Input

```v
import gui

fn login_form(window &gui.Window) gui.View {
	return gui.column(
		content: [
			gui.input(
				id_focus:    1 // Auto-focused on load
				placeholder: 'Username'
			),
			gui.input(
				id_focus:    2
				placeholder: 'Password'
				is_password: true
			),
			gui.button(
				id_focus: 3
				content:  [gui.text(text: 'Login')]
			),
		]
	)
}
```

### Focus Trap (Modal Dialog)

```oksyntax
gui.dialog(
	id_focus: 1
	content: [
		gui.input(id_focus: 2),
		gui.button(id_focus: 3, content: [gui.text(text: 'OK')]),
		gui.button(id_focus: 4, content: [gui.text(text: 'Cancel')]),
	]
)
```

Focus cycles within the dialog, preventing escape to background.

## Related Topics

- **[Events](../core/events.md)** - Keyboard events
- **[Inputs](../components/inputs.md)** - Focusable inputs
- **[Accessibility](accessibility.md)** - Screen reader support