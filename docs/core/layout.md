# Layout

The layout system arranges UI elements using flex-box inspired rows and
columns. Elements are positioned relatively rather than with absolute x,y
coordinates.

## Rows and Columns

### Row: Left-to-Right Axis

A row stacks children horizontally:

```v
import gui

gui.row(
	spacing: 10
	content: [
		gui.text(text: 'Left'),
		gui.text(text: 'Center'),
		gui.text(text: 'Right'),
	]
)
```

Children are placed left-to-right with `spacing` logical pixels between
each.

### Column: Top-to-Bottom Axis

A column stacks children vertically:

```v
import gui

gui.column(
	spacing: 10
	content: [
		gui.text(text: 'Top'),
		gui.text(text: 'Middle'),
		gui.text(text: 'Bottom'),
	]
)
```

Children are placed top-to-bottom with `spacing` logical pixels between
each.

##Canvas: Free-Form Positioning

Canvas provides absolute positioning within a container:

```oksyntax
gui.canvas(
	width:   300
	height:  300
	content: [
		gui.text(text: 'At 10,20', x: 10, y: 20),
		gui.text(text: 'At 50,100', x: 50, y: 100),
	]
)
```

Use canvas for:
- Custom layouts
- Overlapping elements  
- Positioned tooltips or popovers

## Layout Properties

### Spacing

Gap between children along the container's axis:

```oksyntax
gui.column(
	spacing: 15  // 15 logical pixels between children
	content: [...]
)
```

### Padding

Inner margin around content (see [Views](views.md) for diagram):

```oksyntax
gui.column(
	padding: gui.padding_medium  // {10, 10, 10, 10}
	content: [...]
)
```

### Sizing

Each axis can be `fit`, `fill`, or `fixed`. See [Sizing &
Alignment](sizing-alignment.md) for details.

### Alignment

Position children within the container:

```oksyntax
gui.column(
	h_align: .center  // Horizontal: .left, .center, .right
	v_align: .middle  // Vertical: .top, .middle, .bottom
	content: [...]
)
```

## Layout Algorithm

v-gui uses a multi-pass layout algorithm:

### 1. Remove Floating Layouts

Elements with `float: true` are removed from normal flow and positioned
later.

### 2. Width Pass

Calculate widths horizontally:

**For rows (along axis)**:
- `fit`: Sum child widths + spacing
- `fixed`: Use specified width
- `fill`: Distribute remaining space among fill children

**For columns (across axis)**:
- Width is max of children widths

### 3. Fill Width Distribution

For rows with `fill` sizing, distribute remaining horizontal space:

1. Find all children with width sizing = `fill`
2. Grow smallest fills to match next-smallest
3. Distribute remaining space evenly
4. Respect min/max width constraints

### 4. Height Pass

Calculate heights vertically (same logic as width pass, but reversed).

### 5. Fill Height Distribution

Distribute remaining vertical space (same as fill width).

### 6. Positioning

Position each element based on:
- Parent position
- Alignment settings
- Padding
- Spacing

### 7. Floating Layouts

Position floating elements absolutely, relative to their clip parent.

## Logical Pixels

v-gui uses "logical pixels" instead of physical pixels. Logical pixels are
scaled to match physical pixels based on DPI, preserving visual size across
displays.

Example: On a 2x Retina display, 1 logical pixel = 2 physical pixels.

This ensures:
- Consistent visual appearance
- Circles remain circles (aspect ratio preserved)
- Text is readable at all DPIs

##Nesting

Rows and columns can be nested arbitrarily:

```v
import gui

gui.column(
	content: [
		gui.row(
			content: [
				gui.text(text: 'Row 1, Col 1'),
				gui.text(text: 'Row 1, Col 2'),
			]
		),
		gui.row(
			content: [
				gui.text(text: 'Row 2, Col 1'),
				gui.text(text: 'Row 2, Col 2'),
			]
		),
	]
)
```

Result (visual):
```
| Row 1, Col 1 | Row 1, Col 2 |
| Row 2, Col 1 | Row 2, Col 2 |
```

## Scrolling

Containers can scroll when content exceeds dimensions:

```oksyntax
gui.container(
	id_scroll: 1  // Enable scrolling
	width:     200
	height:    300
	content: [
		// Content larger than 200x300 will scroll
		gui.text(text: 'Very long content...')
	]
)
```

See [Scrolling guide](../guides/scrolling.md) for details.

## Performance

Layout calculation is optimized:
- **O(n) complexity** where n = number of views
- **Typical time**: < 1ms for hundreds of elements
- **Early exit**: Stops when sizes stabilize
- **Caching**: Reuses calculations when possible

This allows regenerating layout thousands of times per second.

## Common Patterns

### Responsive Layout

Size the root view to match window:

```oksyntax
fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	return gui.column(
		width:  w
		height: h
		sizing: gui.fixed_fixed
		content: [...]
	)
}
```

When the window resizes, the view regenerates with new dimensions.

### Fixed Header with Scrolling Body

```oksyntax
gui.column(
	content: [
		gui.row(
			height: 50
			sizing: gui.fill_fixed  // Fill width, fixed height
			content: [...header content...]
		),
		gui.container(
			id_scroll: 1
			sizing:    gui.fill_fill  // Fill remaining space
			content: [...scrollable body...]
		),
	]
)
```

### Centered Content

```oksyntax
gui.column(
	h_align: .center
	v_align: .middle
	content: [
		gui.text(text: 'Centered!')
	]
)
```

### Evenly Spaced Buttons

```oksyntax
gui.row(
	spacing: 10
	content: [
		gui.button(sizing: gui.fill_fit, content: [...]),
		gui.button(sizing: gui.fill_fit, content: [...]),
		gui.button(sizing: gui.fill_fit, content: [...]),
	]
)
```

All buttons grow equally to fill the row.

## Related Topics

- **[Views](views.md)** - View primitives and composition
- **[Sizing & Alignment](sizing-alignment.md)** - Size control details
- **[Responsive Layouts](../guides/responsive-layouts.md)** - Adaptive
  design patterns
- **[Scrolling](../guides/scrolling.md)** - Scrollable containers