# Window API

Window creation, configuration, and management.

## window()

Create and configure a window.

```oksyntax
import gui

mut window := gui.window(
	width:     800
	height:    600
	title:     'My Application'
	state:     &App{}
	resizable: true
	on_init:   fn (mut w gui.Window) {
		w.update_view(main_view)
	}
	on_resize: fn (mut w gui.Window) {
		// Optional resize handler
	}
)
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `width` | `int` | Initial window width |
| `height` | `int` | Initial window height |
| `title` | `string` | Window title |
| `state` | `voidptr` | Application state reference |
| `resizable` | `bool` | Allow window resizing |
| `on_init` | `fn` | Initialization callback |
| `on_resize` | `fn` | Resize callback |
| `on_frame` | `fn` | Frame callback (animation) |

## Window Methods

### window.run()

Start the event loop:

```oksyntax
window.run()
```

Blocks until window closes.

### window.update_view()

Set or update the view generator:

```oksyntax
window.update_view(main_view)
```

Call from event handlers or background threads to regenerate the view.

### window.window_size()

Get current window dimensions:

```oksyntax
w, h := window.window_size()
```

Returns `(int, int)` - width and height in logical pixels.

### window.set_theme()

Change the active theme:

```oksyntax
window.set_theme(gui.theme_dark)
```

### window.state[]

Access typed state:

```oksyntax
// Read-only
app := window.state[App]()

// Mutable
mut app := window.state[App]()
app.counter += 1
```

## Lifecycle

```
1. Create window with gui.window()
2. Call window.run()
   ↓
3. on_init callback fires
   ↓
4. Initial view generated
   ↓
5. Event loop runs
   - Handle events
   - Call on_frame (if set)
   - Regenerate view when needed
   ↓
6. Window closes
7. window.run() returns
```

## Related Topics

- **[State Management](../core/state-management.md)** - Window state
- **[Events](../core/events.md)** - Event handling
- **[Themes](../core/themes.md)** - Window theming