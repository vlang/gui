# v-gui Documentation

v-gui is an immediate mode UI framework for the V programming language based
on the rendering algorithm of Clay. It provides a modern, declarative
approach to building user interfaces with flex-box style layout syntax and
thread-safe view updates.

## Quick Links

- **[Quick Start](QUICK-START.md)** - Build your first app in 5 minutes
- **[Architecture](ARCHITECTURE.md)** - Understanding v-gui's design
- **[Examples](examples/)** - Code examples and walkthroughs
- **[API Reference](api/)** - Complete type and function reference

## Core Concepts

Essential concepts to understand v-gui:

- **[Views](core/views.md)** - Building blocks of UI (containers, text,
  images)
- **[Layout](core/layout.md)** - Rows, columns, and positioning
- **[Sizing & Alignment](core/sizing-alignment.md)** - Control element
  dimensions
- **[Themes](core/themes.md)** - Color schemes and visual styling
- **[Styles](core/styles.md)** - Per-component style configuration
- **[Events](core/events.md)** - Mouse, keyboard, and window events
- **[State Management](core/state-management.md)** - Handle application
  state
- **[Fonts](core/fonts.md)** - Typography and text rendering

## Components

UI components organized by function:

- **[Component Index](components/README.md)** - Complete component catalog
- **[Containers](components/containers.md)** - row, column, canvas,
  container
- **[Text & Images](components/text-and-images.md)** - text, image, rtf
- **[Inputs](components/inputs.md)** - input, input_date, select
- **[Buttons](components/buttons.md)** - button, toggle, switch, radio
- **[Pickers & Sliders](components/pickers-and-sliders.md)** - date_picker,
  range_slider
- **[Lists & Tables](components/lists-and-tables.md)** - listbox, table,
  tree
- **[Menus](components/menus.md)** - menu, menu_item, menubar
- **[Dialogs & Panels](components/dialogs-and-panels.md)** - dialog,
  expand_panel, tooltip
- **[Indicators](components/indicators.md)** - progress_bar, pulsar,
  scrollbar

## Guides

Practical how-to documentation:

- **[Creating Custom Views](guides/creating-custom-views.md)** - Build
  reusable components
- **[Responsive Layouts](guides/responsive-layouts.md)** - Adapt to window
  resize
- **[Animation](guides/animation.md)** - Animate UI elements
- **[Scrolling](guides/scrolling.md)** - Scrollable containers
- **[Focus Management](guides/focus-management.md)** - Keyboard navigation
- **[Accessibility](guides/accessibility.md)** - Accessible interfaces
- **[Debugging](guides/debugging.md)** - Troubleshooting tips

## Installation

Install v-gui using V's package manager:

```bash
v install gui
```

## Your First App

```v
import gui

struct App {
pub mut:
	clicks int
}

fn main() {
	mut window := gui.window(
		state:   &App{}
		width:   300
		height:  300
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[App]()
	return gui.column(
		width:   w
		height:  h
		h_align: .center
		v_align: .middle
		sizing:  gui.fixed_fixed
		content: [
			gui.text(text: 'Welcome to v-gui'),
			gui.button(
				content:  [gui.text(text: '${app.clicks} Clicks')]
				on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[App]()
					app.clicks += 1
				}
			),
		]
	)
}
```

See [Quick Start](QUICK-START.md) for a detailed walkthrough.

## Key Features

- **Pure V**: Written entirely in the V programming language
- **Immediate Mode**: Efficient rendering with automatic updates
- **Thread Safe**: Safe view updates across threads
- **Declarative**: Flex-box style layout with intuitive API
- **Performance**: Optimized for speed and efficiency

## Getting Help

- Browse the [examples folder](examples/) for working code
- Check the [API reference](api/) for detailed type information
- Review [guides](guides/) for common patterns and best practices
- Visit the [GitHub repository](https://github.com/vlang/gui) for issues
  and contributions

## Contributing

Contributions are welcome! Visit the GitHub repository to:

- Report issues
- Submit pull requests
- Provide feedback
- Help with documentation
