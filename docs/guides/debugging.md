# Debugging

Tools and techniques for debugging v-gui applications.

## Print Debugging

Use `println` in view generators and event handlers:

```v
import gui

fn debug_view(window &gui.Window) gui.View {
	app := window.state[App]()
	println('View regenerated. Counter: ${app.counter}')

	return gui.button(
		content:  [gui.text(text: '${app.counter}')]
		on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
			println('Button clicked')
			mut app := w.state[App]()
			app.counter += 1
			println('New counter value: ${app.counter}')
		}
	)
}
```

## Layout Inspection

Inspect layout dimensions and positions:

```oksyntax
on_click: fn (layout &gui.Layout, mut e gui.Event, mut w gui.Window) {
	println('Width: ${layout.shape.width}')
	println('Height: ${layout.shape.height}')
	println('X: ${layout.shape.x}')
	println('Y: ${layout.shape.y}')
}
```

## Event Debugging

Log all events:

```oksyntax
on_click: fn (layout &gui.Layout, mut e gui.Event, mut w gui.Window) {
	println('Event type: ${e.typ}')
	println('Mouse position: (${e.mouse_x}, ${e.mouse_y})')
	println('Key code: ${e.key_code}')
}
```

## State Inspection

Print state changes:

```v
import gui

fn debug_state_view(window &gui.Window) gui.View {
	app := window.state[App]()

	// Print state on every regeneration
	println('=== State ===')
	println('Counter: ${app.counter}')
	println('Text: "${app.text}"')
	println('Items: ${app.items}')

	return gui.text(text: 'Check console for state')
}
```

## Visual Debugging

Add visual debugging aids:

```v
import gui

fn visual_debug(window &gui.Window) gui.View {
	return gui.column(
		fill:    true
		color:   gui.rgb(255, 0, 0) // Red background for debugging
		padding: gui.padding_medium
		content: [
			gui.text(text: 'Debug view'),
		]
	)
}
```

## Common Issues

### View Not Updating

**Problem**: State changes but view doesn't update.

**Solution**: Ensure `update_view()` is called (automatic in event handlers,
manual in background threads):

```v
import gui

spawn fn (mut w gui.Window) {
	// Background work
	mut app := w.state[App]()
	app.result = calculate()
	w.update_view(main_view) // Required!
}(mut window)
```

### Layout Issues

**Problem**: Elements sized or positioned incorrectly.

**Solution**: Check `sizing` modes and constraints:

```v
import gui

gui.column(
	width:     300
	height:    200
	sizing:    gui.fixed_fixed // Explicit sizing
	min_width: 100
	max_width: 500
	content:   [
		gui.text(text: 'Sized element'),
	]
)
```

### Event Not Firing

**Problem**: Event handler not called.

**Solution**: 
1. Check component isn't `disabled`
2. Ensure component is visible
3. Verify no overlapping elements
4. Check `focus_skip` isn't preventing focus

### Performance Issues

**Problem**: UI feels slow.

**Solution**:
1. Profile view generation time
2. Minimize state size
3. Avoid expensive computations in view generators
4. Use background threads for heavy work

## Debugging Tools

### V Compiler Flags

```bash
v -g your_app.v        # Debug symbols
v -cg your_app.v       # C debug symbols
v -stats your_app.v    # Show compilation stats
```

### Profiling

Use V's built-in profiler:

```v
import time

fn main() {
	sw := time.new_stopwatch()
	// ... your code ...
	println('Elapsed: ${sw.elapsed().milliseconds()} ms')
}
```

## Tips

- **Start simple**: Build incrementally, test often
- **Isolate issues**: Create minimal reproductions
- **Check examples**: Compare with working examples
- **Read error messages**: V's errors are usually informative
- **Use version control**: Commit working states frequently

## Related Topics

- **[State Management](../core/state-management.md)** - State debugging
- **[Events](../core/events.md)** - Event handling
- **[Layout](../core/layout.md)** - Layout algorithm