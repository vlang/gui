# Animation

v-gui handles animation through a dedicated `Animate` struct and the `window.animation_add` 
method. This system manages timing, callbacks, and screen refreshes efficiently.

## The Animate Struct

To create an animation, you define an `Animate` struct and register it with the window.

```oksyntax
pub struct Animate {
pub:
	id       string                       @[required]
	callback fn (mut Animate, mut Window) @[required]
mut:
	delay   time.Duration = 500 * time.millisecond
	start   time.Time
	stopped bool
	repeat  bool
}
```

### Fields

- **id**: A unique identifier for the animation. Using the same ID will replace an existing 
animation.
- **callback**: The function to call when the animation triggers. It receives the `Animate` 
instance and the `Window`.
- **delay**: The time to wait before the next callback trigger. Defaults to 500ms.
- **repeat**: If `true`, the animation restarts after the callback returns.
- **stopped**: Set to `true` to stop the animation.

## Creating an Animation

Use `window.animation_add()` to register your animation. This automatically handles the animation 
loop and updates the window when necessary.

### Example: Blinking Cursor

Here is an example of how to implement a blinking cursor animation.

```oksyntax
import gui

fn start_blinky_(mut window gui.Window) {
	window.animation_add(mut gui.Animate{
		id:       '___blinky_cursor_animation___'
		delay:    600 * time.millisecond
		repeat:   true
		callback: fn (mut an gui.Animate, mut w gui.Window) {
			// Toggle cursor state
			app.blink = !app.blink
		}
	})
}
```

## Managing Animations

- **Add/Replace**: `window.animation_add(mut animation)` adds a new animation or replaces one with
the same ID.
- **Remove**: `window.remove_animation(id)` stops and removes an animation by its ID.
- **Check**: `window.has_animation(id)` checks if an animation is currently active.