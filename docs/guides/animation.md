# Animation

v-gui supports animation through state-driven approaches and time-based
updates.

## State-Driven Animation

The simplest approach: change state over time, triggering view regeneration.

### Timer-Based Animation

```v
import gui
import time

struct App {
pub mut:
	rotation f32
}

fn animated_view(window &gui.Window) gui.View {
	app := window.state[App]()

	// Spawn animation loop on first render
	spawn fn (mut w gui.Window) {
		for {
			time.sleep(16 * time.millisecond) // ~60 FPS
			mut app := w.state[App]()
			app.rotation += 2.0
			if app.rotation >= 360 {
				app.rotation = 0
			}
			w.update_view(animated_view)
		}
	}(mut window)

	return gui.text(text: 'Rotation: ${app.rotation}')
}
```

### Frame-Based Animation

Use v-gui's frame callback for smoother animation:

```oksyntax
gui.window(
	on_frame: fn (mut w gui.Window, dt f32) {
		mut app := w.state[App]()
		app.rotation += dt * 90.0 // 90 degrees per second
		w.update_view(animated_view)
	}
)
```

## Transitions

Animate between states smoothly:

```v
import gui
import math

struct App {
pub mut:
	target_x  f32
	current_x f32
}

fn lerp(a f32, b f32, t f32) f32 {
	return a + (b - a) * t
}

fn smooth_transition(window &gui.Window) gui.View {
	mut app := window.state[App]()

	// Smoothly interpolate to target
	app.current_x = lerp(app.current_x, app.target_x, 0.1)

	return gui.canvas(
		width:   400
		height:  300
		content: [
			gui.text(text: '●', x: app.current_x, y: 150),
		]
	)
}
```

## Animation Patterns

### Fade In/Out

```v
import gui

struct App {
pub mut:
	opacity f32 = 1.0
}

fn fade_view(window &gui.Window) gui.View {
	app := window.state[App]()
	return gui.column(
		color:   gui.rgba(0, 0, 0, int(app.opacity * 255))
		content: [gui.text(text: 'Fading...')]
	)
}
```

### Progress Animation

```v
import gui
import time

struct App {
pub mut:
	progress f32
}

fn progress_view(window &gui.Window) gui.View {
	app := window.state[App]()
	return gui.progress_bar(progress: app.progress)
}

// In background thread
spawn fn (mut w gui.Window) {
	for i := 0; i <= 100; i++ {
		time.sleep(50 * time.millisecond)
		mut app := w.state[App]()
		app.progress = f32(i) / 100.0
		w.update_view(progress_view)
	}
}(mut window)
```

### Loading Spinner

Use the built-in `pulsar` component:

```v
import gui

gui.pulsar(size: 60)
```

## Performance Tips

- **Limit frame rate**: 60 FPS is usually sufficient
- **Update only what changes**: Don't regenerate entire view if only one
  element animates
- **Use background threads**: Keep animation logic off the main thread
- **Profile**: v-gui's layout is fast (< 1ms for hundreds of elements)

## Related Topics

- **[State Management](../core/state-management.md)** - State updates
- **[Indicators](../components/indicators.md)** - Progress and loading