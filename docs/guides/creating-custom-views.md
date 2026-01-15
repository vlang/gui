# Creating Custom Views

Build reusable components from primitives.

## Understanding Custom Views

Custom views are functions that return `View` objects. They encapsulate
layouts and styling for reuse.

### Basic Custom View

```v
import gui

fn card(title string, content string) gui.View {
	return gui.column(
		padding: gui.padding_medium
		fill:    true
		color:   gui.theme().color_panel
		radius:  8
		content: [
			gui.text(text: title, text_style: gui.theme().b3),
			gui.text(text: content),
		]
	)
}

// Usage
fn main_view(window &gui.Window) gui.View {
	return gui.column(
		content: [
			card('Title 1', 'Content 1'),
			card('Title 2', 'Content 2'),
		]
	)
}
```

## Parameterized Components

Accept configuration parameters:

```v
import gui

struct CardConfig {
	title   string
	content string
	color   gui.Color = gui.theme().color_panel
	width   f32       = 300
}

fn card(cfg CardConfig) gui.View {
	return gui.column(
		width:   cfg.width
		padding: gui.padding_medium
		fill:    true
		color:   cfg.color
		radius:  8
		content: [
			gui.text(text: cfg.title, text_style: gui.theme().b3),
			gui.text(text: cfg.content),
		]
	)
}

// Usage
card(CardConfig{
	title:   'Custom Card'
	content: 'With parameters'
	color:   gui.rgb(240, 240, 245)
})
```

## Stateful Components

Components that access window state:

```v
import gui

struct App {
pub mut:
	count int
}

fn counter_button(window &gui.Window) gui.View {
	app := window.state[App]()
	return gui.button(
		content:  [gui.text(text: 'Count: ${app.count}')]
		on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
			mut app := w.state[App]()
			app.count += 1
		}
	)
}
```

## Common Patterns

### Icon Button

```v
import gui

fn icon_button(icon string, label string, on_click fn (&gui.Layout, mut gui.Event, mut gui.Window)) gui.View {
	return gui.button(
		content:  [
			gui.text(text: icon, text_style: gui.theme().icon3),
			gui.text(text: label),
		]
		on_click: on_click
	)
}

// Usage
icon_button(gui.icon_save, 'Save', fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
	save_document()
})
```

### Labeled Input

```v
import gui

fn labeled_input(label string, value string, on_change fn (&gui.Layout, mut gui.Event, mut gui.Window)) gui.View {
	return gui.column(
		spacing: 5
		content: [
			gui.text(text: label, text_style: gui.theme().n4),
			gui.input(
				text:            value
				on_text_changed: on_change
			),
		]
	)
}
```

### Alert Box

```v
import gui

enum AlertType {
	info
	warning
	error
}

fn alert_box(message string, alert_type AlertType) gui.View {
	color := match alert_type {
		.info { gui.rgb(0, 120, 255) }
		.warning { gui.rgb(255, 149, 0) }
		.error { gui.rgb(255, 59, 48) }
	}

	return gui.row(
		padding: gui.padding_medium
		fill:    true
		color:   color
		radius:  4
		content: [
			gui.text(
				text:       message
				text_style: gui.TextStyle{
					...gui.theme().text_style
					color: gui.rgb(255, 255, 255)
				}
			),
		]
	)
}
```

### List Item

```v
import gui

struct ListItemConfig {
	title    string
	subtitle string
	icon     string
	on_click fn (&gui.Layout, mut gui.Event, mut gui.Window)
}

fn list_item(cfg ListItemConfig) gui.View {
	return gui.button(
		content:  [
			gui.row(
				spacing: 10
				content: [
					gui.text(text: cfg.icon, text_style: gui.theme().icon3),
					gui.column(
						content: [
							gui.text(text: cfg.title, text_style: gui.theme().b4),
							gui.text(text: cfg.subtitle, text_style: gui.theme().n5),
						]
					),
				]
			),
		]
		on_click: cfg.on_click
	)
}
```

## Component Libraries

Organize custom views in modules:

```v
// components.v
module components

import gui

pub fn primary_button(label string, on_click fn (&gui.Layout, mut gui.Event, mut gui.Window)) gui.View {
	return gui.button(
		content:  [gui.text(text: label)]
		style:    gui.ButtonStyle{
			...gui.theme().button_style
			color_background: gui.rgb(0, 120, 255)
			color:            gui.rgb(255, 255, 255)
		}
		on_click: on_click
	)
}

pub fn danger_button(label string, on_click fn (&gui.Layout, mut gui.Event, mut gui.Window)) gui.View {
	return gui.button(
		content:  [gui.text(text: label)]
		style:    gui.ButtonStyle{
			...gui.theme().button_style
			color_background: gui.rgb(255, 59, 48)
			color:            gui.rgb(255, 255, 255)
		}
		on_click: on_click
	)
}
```

```v
// main.v
import gui
import components

fn view(window &gui.Window) gui.View {
	return gui.row(
		content: [
			components.primary_button('Save', handle_save),
			components.danger_button('Delete', handle_delete),
		]
	)
}
```

## Best Practices

1. **Keep components focused**: Each component should do one thing well
2. **Use configuration structs**: For components with many parameters
3. **Avoid side effects**: Components should be pure functions
4. **Leverage composition**: Build complex components from simpler ones
5. **Document parameters**: Explain what each parameter does

## Related Topics

- **[Views](../core/views.md)** - View primitives
- **[Containers](../components/containers.md)** - Container components
- **[State Management](../core/state-management.md)** - Component state