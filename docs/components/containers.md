# Containers

Containers organize and position child views. v-gui provides four container
types: row, column, canvas, and container.

## row

Stacks children horizontally (left-to-right).

### Basic Usage

```v
import gui

gui.row(
	spacing: 10
	content: [
		gui.text(text: 'First'),
		gui.text(text: 'Second'),
		gui.text(text: 'Third'),
	]
)
```

Result: `[First]  [Second]  [Third]`

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `content` | `[]View` | Child views to stack |
| `spacing` | `f32` | Gap between children (logical pixels) |
| `h_align` | `Alignment` | Horizontal alignment: `.left`, `.center`, `.right` |
| `v_align` | `Alignment` | Vertical alignment: `.top`, `.middle`, `.bottom` |
| `padding` | `Padding` | Inner margin |
| `sizing` | `Sizing` | Size mode (fit/fill/fixed) |
| `width`, `height` | `f32` | Dimensions |
| `id_scroll` | `int` | Enable scrolling (non-zero) |

### Common Patterns

**Evenly spaced buttons:**
```v
import gui

gui.row(
	spacing: 10
	content: [
		gui.button(sizing: gui.fill_fit, content: [gui.text(text: 'OK')]),
		gui.button(sizing: gui.fill_fit, content: [gui.text(text: 'Cancel')]),
	]
)
```

**Toolbar:**
```oksyntax
gui.row(
	h_align: .left
	padding: gui.padding_small
	content: [
		gui.button(content: [gui.text(text: 'File')]),
		gui.button(content: [gui.text(text: 'Edit')]),
		gui.button(content: [gui.text(text: 'View')]),
	]
)
```

## column

Stacks children vertically (top-to-bottom).

### Basic Usage

```v
import gui

gui.column(
	spacing: 10
	content: [
		gui.text(text: 'First'),
		gui.text(text: 'Second'),
		gui.text(text: 'Third'),
	]
)
```

Result:
```
[First]
[Second]
[Third]
```

### Key Properties

Same as row, but `spacing` applies vertically.

### Common Patterns

**Form layout:**
```oksyntax
import gui

struct App_2 {
pub mut:
	name string
}

fn form_view(window &gui.Window) gui.View {
	return gui.column(
		spacing: 10
		padding: gui.padding_medium
		content: [
			gui.text(text: 'Name:'),
			gui.input(),
			gui.text(text: 'Email:'),
			gui.input(),
			gui.button(content: [gui.text(text: 'Submit')]),
		]
	)
}
```

**Scrollable list:**
```oksyntax
gui.column(
	id_scroll: 1 // Enable vertical scrolling
	height:    300
	sizing:    gui.fixed_fill
	content:   items.map(fn (item string) gui.View {
		return gui.text(text: item)
	})
)
```

## canvas

Free-form positioning (no axis). Children use explicit coordinates.

### Basic Usage

```oksyntax
gui.canvas(
	width:   400
	height:  300
	content: [
		gui.text(text: 'Positioned', x: 50, y: 100),
		gui.button(x: 200, y: 150, content: [gui.text(text: 'Click')]),
	]
)
```

### When to Use

- Custom layouts
- Overlapping elements
- Games or visualizations
- Positioned tooltips

### Limitations

Canvas doesn't provide automatic layout. You must specify positions
manually. For most UI layouts, use row and column instead.

## container

Generic scrollable container with additional features.

### Basic Usage

```oksyntax
import gui

gui.container(
	id_scroll: 1
	width:     400
	height:    300
	content:   [
		gui.column(
			content: [
				// Many child views...
			]
		),
	]
)
```

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `id_scroll` | `int` | Enable scrolling |
| `scroll_mode` | `ScrollMode` | Restrict to h/v only |
| `scrollbar_visible` | `bool` | Show scrollbars |
| `clip` | `bool` | Clip overflow |

### Scrolling

Enable scrolling with `id_scroll`:

```oksyntax
gui.container(
	id_scroll: 1 // Unique non-zero ID
	width:     200
	height:    300
	content:   [
		// Content larger than 200x300 will scroll
	]
)
```

v-gui remembers scroll positions by `id_scroll`, so the same ID across
sessions will restore scroll position.

## Nested Containers

Containers can be nested arbitrarily:

```v
import gui

gui.column(
	content: [
		gui.row(
			content: [
				gui.text(text: 'Top-left'),
				gui.text(text: 'Top-right'),
			]
		),
		gui.row(
			content: [
				gui.text(text: 'Bottom-left'),
				gui.text(text: 'Bottom-right'),
			]
		),
	]
)
```

Creates a 2x2 grid layout.

## Styling Containers

Containers support visual styling:

```v
import gui

gui.column(
	fill:    true // Fill background
	color:   gui.rgb(240, 240, 245) // Background color
	radius:  8 // Rounded corners
	padding: gui.padding_medium
	content: [
		gui.text(text: 'Card content'),
	]
)
```

Creates a rounded, colored panel.

## Buttons are Containers

Buttons are built from rows:

```oksyntax
gui.row(
	// Outer row = border/background
	padding: border_padding
	color:   border_color
	content: [
		gui.row(
			// Inner row = button body
			padding: interior_padding
			color:   interior_color
			content: [
				gui.text(text: 'Button Text')
			]
		),
	]
)
```

Because buttons are containers, they can hold any views:

```oksyntax
import gui

gui.button(
	content: [
		gui.image(path: 'icon.png', width: 16, height: 16),
		gui.text(text: 'Save'),
	]
)
```

## Floating Containers

Containers can float over other content (useful for menus, tooltips):

```oksyntax
gui.column(
	float:   true // Float over other content
	padding: gui.padding_small
	fill:    true
	radius:  4
	content: [
		// Menu items
	]
)
```

## Focus and Keyboard Navigation

Containers can receive keyboard focus:

```oksyntax
gui.column(
	id_focus: 1 // Focus order
	content:  [...]
)
```

Use `id_focus` to control tab order. Lower numbers receive focus first.

## Related Topics

- **[Layout](../core/layout.md)** - Layout algorithm
- **[Sizing & Alignment](../core/sizing-alignment.md)** - Size control
- **[Scrolling](../guides/scrolling.md)** - Scrollable containers
- **[Views](../core/views.md)** - View composition