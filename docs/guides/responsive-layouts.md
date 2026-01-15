# Responsive Layouts

Build UIs that adapt to window size.

## Window-Sized Root View

Size the root view to match the window:

```v
import gui

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		content: [
			// Content fills window
		]
	)
}
```

The view regenerates automatically when the window resizes.

## Fill Sizing

Use `fill` sizing to consume available space:

```v
import gui

fn responsive_layout(window &gui.Window) gui.View {
	w, h := window.window_size()
	return gui.row(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		content: [
			gui.column(
				width:   200
				sizing:  gui.fixed_fill // Fixed width, fill height
				content: [// sidebar]
			),
			gui.column(
				sizing:  gui.fill_fill // Fill remaining space
				content: [// main content]
			),
		]
	)
}
```

## Breakpoints

Adapt layout based on window width:

```v
import gui

fn responsive_view(window &gui.Window) gui.View {
	w, h := window.window_size()

	if w < 600 {
		// Mobile layout: single column
		return gui.column(
			width:   w
			height:  h
			sizing:  gui.fixed_fixed
			content: [
				header_mobile(),
				content_mobile(),
			]
		)
	} else {
		// Desktop layout: sidebar + main
		return gui.row(
			width:   w
			height:  h
			sizing:  gui.fixed_fixed
			content: [
				sidebar(),
				main_content(),
			]
		)
	}
}
```

## Flexible Grids

Create responsive grids with `fill` sizing:

```v
import gui

fn grid_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		content: [
			gui.row(
				sizing:  gui.fill_fit
				content: [
					gui.button(
						sizing:  gui.fill_fit
						content: [
							gui.text(text: '1'),
						]
					),
					gui.button(
						sizing:  gui.fill_fit
						content: [
							gui.text(text: '2'),
						]
					),
					gui.button(
						sizing:  gui.fill_fit
						content: [
							gui.text(text: '3'),
						]
					),
				]
			),
			gui.row(
				sizing:  gui.fill_fit
				content: [
					gui.button(
						sizing:  gui.fill_fit
						content: [
							gui.text(text: '4'),
						]
					),
					gui.button(
						sizing:  gui.fill_fit
						content: [
							gui.text(text: '5'),
						]
					),
					gui.button(
						sizing:  gui.fill_fit
						content: [
							gui.text(text: '6'),
						]
					),
				]
			),
		]
	)
}
```

Each button grows equally to fill available width.

## Common Patterns

### App Shell

```v
import gui

fn app_shell(window &gui.Window) gui.View {
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
				content: [// header]
			),
			// Flexible body
			gui.row(
				sizing:  gui.fill_fill
				content: [
					// Sidebar (optional on small screens)
					if w >= 768 {
						gui.column(
							width:   250
							sizing:  gui.fixed_fill
							content: [// sidebar]
						)
					} else {
						gui.text(text: '')
					},
					// Main content
					gui.column(
						sizing:  gui.fill_fill
						content: [// content]
					),
				]
			),
		]
	)
}
```

### Responsive Cards

```v
import gui

fn card_grid(window &gui.Window, items []string) gui.View {
	w, _ := window.window_size()

	// Determine columns based on width
	cols := if w < 600 {
		1 // Mobile: 1 column
	} else if w < 900 {
		2 // Tablet: 2 columns
	} else {
		3 // Desktop: 3 columns
	}

	mut rows := []gui.View{}
	for i := 0; i < items.len; i += cols {
		end := if i + cols > items.len { items.len } else { i + cols }
		row_items := items[i..end]

		rows << gui.row(
			spacing: 10
			content: row_items.map(fn (item string) gui.View {
				return gui.column(
					sizing:  gui.fill_fit
					content: [gui.text(text: item)]
				)
			})
		)
	}

	return gui.column(
		spacing: 10
		content: rows
	)
}
```

## Related Topics

- **[Sizing & Alignment](../core/sizing-alignment.md)** - Sizing modes
- **[Layout](../core/layout.md)** - Layout system
- **[Containers](../components/containers.md)** - Container types