# Scrolling

Create scrollable containers for content that exceeds available space.

## Basic Scrolling

Enable scrolling with `id_scroll`:

```oksyntax
import gui

gui.column(
	id_scroll: 1 // Any non-zero ID
	width:     300
	height:    400
	content:   [
		gui.column(
			content: items.map(fn (item string) gui.View {
				return gui.text(text: item)
			})
		),
	]
)
```

When content height exceeds 400 pixels, scrolling activates automatically.

## Scroll Position Persistence

v-gui remembers scroll positions by `id_scroll`. Use consistent IDs:

```oksyntax
import gui

// Same id_scroll across sessions = remembered scroll position
gui.column(
	id_scroll: 1
	content:   [long_content()]
)
```

## Vertical-Only Scrolling

Restrict to vertical scrolling:

```oksyntax
gui.column(
	id_scroll:   1
	scroll_mode: .vertical_only
	content:     [...]
)
```

## Horizontal-Only Scrolling

Restrict to horizontal scrolling:

```oksyntax
gui.column(
	id_scroll:   1
	scroll_mode: .horizontal_only
	content:     [...]
)
```

## Scrollbar Visibility

Control scrollbar display:

```oksyntax
gui.column(
	id_scroll:         1
	scrollbar_visible: true // Always show scrollbars
	content:           [...]
)
```

Default behavior: scrollbars appear when content overflows.

## Common Patterns

### Scrollable List

```v
import gui

struct App_15 {
pub mut:
	items []string
}

fn list_view(window &gui.Window) gui.View {
	app := window.state[App_15]()
	return gui.column(
		id_scroll: 1
		width:     400
		height:    600
		content:   [
			gui.column(
				spacing: 5
				content: app.items.map(fn (item string) gui.View {
					return gui.text(text: item)
				})
			),
		]
	)
}
```

### Fixed Header with Scrolling Body

```oksyntax
import gui

fn app_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		content: [
			// Fixed header
			gui.row(
				height:  60
				sizing:  gui.fill_fixed
				content: [gui.text(text: 'Header')]
			),
			// Scrollable body
			gui.column(
				id_scroll: 1
				sizing:    gui.fill_fill
				content:   [long_content()]
			),
		]
	)
}
```

### Horizontal Scrolling Gallery

```oksyntax
gui.column(
	id_scroll:   1
	scroll_mode: .horizontal_only
	width:       600
	height:      200
	content: [
		gui.row(
			spacing: 10
			content: images.map(fn (img string) gui.View {
				return gui.image(path: img, width: 180, height: 180)
			})
		),
	]
)
```

### Nested Scrolling

```oksyntax
gui.column(
	id_scroll: 1 // Outer scroll
	width:     800
	height:    600
	content: [
		gui.column(
			content: [
				gui.text(text: 'Section 1'),
				gui.column(
					id_scroll: 2 // Inner scroll
					height:    200
					content:   [inner_content()]
				),
				gui.text(text: 'Section 2'),
			]
		),
	]
)
```

## Tips

- **Unique IDs**: Each scrollable region needs a unique `id_scroll`
- **Performance**: Scrolling hundreds of items is fast (< 1ms layout)
- **Scroll state**: Persists across view regenerations automatically
- **Clipping**: Content outside scroll bounds is clipped automatically

## Related Topics

- **[Containers](../components/containers.md)** - Container components
- **[Layout](../core/layout.md)** - Layout system
- **[Sizing](../core/sizing-alignment.md)** - Container sizing