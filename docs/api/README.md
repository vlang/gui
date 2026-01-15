# API Reference

Complete reference for v-gui types, functions, and utilities.

## Core Types

### Window
Window creation and management.
[View documentation](window.md)

### Layout Types
Layout configuration and sizing.
[View documentation](layout-types.md)

### Theme Types
Theming and styling types.
[View documentation](theme-types.md)

## Utility Functions

Color creation, padding helpers, and other utilities.
[View documentation](utility-functions.md)

## Quick Reference

### Creating a Window

```v
import gui

mut window := gui.window(
	width:   800
	height:  600
	title:   'My App'
	state:   &App{}
	on_init: fn (mut w gui.Window) {
		w.update_view(main_view)
	}
)
window.run()
```

### Sizing Constants

```v
// Sizing modes
gui.fit_fit
gui.fit_fill
gui.fill_fit
gui.fill_fill
gui.fixed_fixed
// ... and 4 more combinations

// Padding
gui.padding_none
// {0, 0, 0, 0}
gui.padding_small
// {5, 5, 5, 5}
gui.padding_medium
// {10, 10, 10, 10}
gui.padding_large
// {15, 15, 15, 15}

// Radius
gui.radius_none
// 0
gui.radius_small
// 4
gui.radius_medium
// 8
gui.radius_large
// 12
```

### Color Functions

```v
// RGB
gui.rgb(255, 100, 0)

// RGBA
gui.rgba(255, 100, 0, 128)

// Hex
gui.hex(0xFF6400)
```

## Component Creation

All components follow the same pattern:

```v
gui.component_name(
	property: value
	content:  [child_views]
	on_event: event_handler
)
```

See [Components](../components/README.md) for complete component list.

## Related Topics

- **[Core Concepts](../core/views.md)** - Fundamental concepts
- **[Components](../components/README.md)** - Component reference
- **[Guides](../guides/creating-custom-views.md)** - Practical guides