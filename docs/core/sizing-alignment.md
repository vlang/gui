# Sizing and Alignment

Control how views determine their dimensions and position within their
parent container.

## Sizing Modes

Each axis (width and height) can use one of three sizing modes:

### Fit

Size to content. The view measures its children and sizes itself
accordingly.

```oksyntax
gui.column(
	sizing: gui.fit_fit  // Fit both width and height to content
	content: [...]
)
```

Use when: The view should be exactly large enough for its content.

### Fill

Grow or shrink to fill available space in the parent.

```oksyntax
gui.column(
	sizing: gui.fill_fill  // Fill both width and height
	content: [...]
)
```

Use when: The view should take up remaining space.

### Fixed

Use the specified width or height exactly.

```oksyntax
gui.column(
	width:  200
	height: 300
	sizing: gui.fixed_fixed  // Use specified dimensions
	content: [...]
)
```

Use when: The view must be a specific size.

## Sizing Combinations

There are nine possible combinations of width/height sizing:

| Constant | Width | Height | Use Case |
|----------|-------|--------|----------|
| `fit_fit` | fit | fit | Size to content both axes |
| `fit_fill` | fit | fill | Width to content, fill height |
| `fit_fixed` | fit | fixed | Width to content, fixed height |
| `fixed_fit` | fixed | fit | Fixed width, height to content |
| `fixed_fill` | fixed | fill | Fixed width, fill height |
| `fixed_fixed` | fixed | fixed | Both dimensions fixed |
| `fill_fit` | fill | fit | Fill width, height to content |
| `fill_fill` | fill | fill | Fill both axes |
| `fill_fixed` | fill | fixed | Fill width, fixed height |

### Examples

**Sidebar with fixed width, full height:**
```oksyntax
gui.column(
	width:  200
	sizing: gui.fixed_fill  // Fixed width, fill height
	content: [...]
)
```

**Header with full width, fixed height:**
```oksyntax
gui.row(
	height: 50
	sizing: gui.fill_fixed  // Fill width, fixed height
	content: [...]
)
```

**Button that grows with siblings:**
```oksyntax
gui.button(
	sizing: gui.fill_fit  // Fill width, fit height to content
	content: [...]
)
```

## Alignment

Control where children are positioned within the parent.

### Horizontal Alignment

- `.left` - Align to left edge
- `.center` - Center horizontally
- `.right` - Align to right edge

```oksyntax
gui.column(
	h_align: .center  // Center children horizontally
	content: [...]
)
```

### Vertical Alignment

- `.top` - Align to top edge
- `.middle` - Center vertically
- `.bottom` - Align to bottom edge

```oksyntax
gui.row(
	v_align: .middle  // Center children vertically
	content: [...]
)
```

### Combined Example

```v
import gui

gui.column(
	width:   300
	height:  300
	sizing:  gui.fixed_fixed
	h_align: .center
	v_align: .middle
	content: [
		gui.text(text: 'Centered both ways!'),
	]
)
```

## Min/Max Constraints

Views can specify minimum and maximum dimensions:

```oksyntax
gui.column(
	min_width:  100
	max_width:  500
	min_height: 50
	max_height: 300
	sizing:     gui.fill_fill
	content: [...]
)
```

The layout engine respects these constraints:
- `fill` sizing won't shrink below `min_*`
- `fill` sizing won't grow beyond `max_*`
- `fit` sizing is clamped to `min_*` and `max_*`

## Sizing in Rows vs Columns

Sizing behavior depends on the container's axis:

### Row (left-to-right)

**Along axis (width)**:
- `fit`: Sum of children widths + spacing
- `fill`: Distribute extra space among fill children
- `fixed`: Use specified width

**Across axis (height)**:
- `fit`: Max of children heights
- `fill`: Grow to parent height
- `fixed`: Use specified height

### Column (top-to-bottom)

**Along axis (height)**:
- `fit`: Sum of children heights + spacing
- `fill`: Distribute extra space among fill children
- `fixed`: Use specified height

**Across axis (width)**:
- `fit`: Max of children widths
- `fill`: Grow to parent width
- `fixed`: Use specified width

## Fill Distribution

When multiple children have `fill` sizing, space is distributed evenly:

```v
import gui

gui.row(
	width:   300
	sizing:  gui.fixed_fit
	content: [
		gui.button(sizing: gui.fill_fit, content: [gui.text(text: 'A')]),
		gui.button(sizing: gui.fill_fit, content: [gui.text(text: 'B')]),
		gui.button(sizing: gui.fill_fit, content: [gui.text(text: 'C')]),
	]
)
```

All three buttons get equal width (100 pixels each, assuming no spacing).

**With constraints:**
```oksyntax
gui.row(
	width:  300
	sizing: gui.fixed_fit
	content: [
		gui.button(
			min_width: 150
			sizing:    gui.fill_fit
			content:   [gui.text(text: 'Wide')]
		),
		gui.button(sizing: gui.fill_fit, content: [gui.text(text: 'B')]),
		gui.button(sizing: gui.fill_fit, content: [gui.text(text: 'C')]),
	]
)
```

First button gets 150px (its minimum). Remaining 150px is split between B
and C (75px each).

## Common Patterns

### Full-Window View

```oksyntax
fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	return gui.column(
		width:  w
		height: h
		sizing: gui.fixed_fixed  // Use exact window dimensions
		content: [...]
	)
}
```

### Flexible Grid

```v
import gui

gui.column(
	sizing:  gui.fill_fill
	content: [
		gui.row(
			sizing:  gui.fill_fit
			content: [
				// gui.button(sizing: gui.fill_fit, content: [...]),
				// gui.button(sizing: gui.fill_fit, content: [...]),
			]
		),
		gui.row(
			sizing:  gui.fill_fit
			content: [
				// gui.button(sizing: gui.fill_fit, content: [...]),
				// gui.button(sizing: gui.fill_fit, content: [...]),
			]
		),
	]
)
```

Creates a 2x2 grid where cells grow to fill available space.

### Sidebar Layout

```v
import gui

gui.row(
	sizing:  gui.fill_fill
	content: [
		gui.column(
			width:  200
			sizing: gui.fixed_fill // Fixed-width sidebar
			// content: [...sidebar content...]
		),
		gui.column(
			sizing: gui.fill_fill // Main content fills remaining space
			// content: [...main content...]
		),
	]
)
```

### Centered Dialog

```v
import gui

gui.column(
	sizing:  gui.fill_fill
	h_align: .center
	v_align: .middle
	content: [
		gui.column(
			width:  400
			height: 300
			sizing: gui.fixed_fixed
			// content: [...dialog content...]
		),
	]
)
```

## Related Topics

- **[Views](views.md)** - View primitives
- **[Layout](layout.md)** - Layout algorithm details
- **[Responsive Layouts](../guides/responsive-layouts.md)** - Adaptive
  patterns