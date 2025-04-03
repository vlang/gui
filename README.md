# GUI

A UI frame work for the V language based on the rendering algorithm of
Clay.

It's early days so little is working. Try it and send feedback.

## Features

- Pure V
- Immediate mode rendering
- Thread safe view updates
- Declarative, flex-box style layout syntax
- Microsecond performance

## Example

```v
import gui
import gg

// GUI uses a view generator (a function that returns a View) to
// render the contents of the Window. As the state of the app
// changes, either through user actions or business logic, GUI
// calls the view generator to build a new view. The new view is
// used to render the contents of the window.
//
// There are several advantages to this approach.
// - The view is simply a function of the model (state).
// - No data binding or other observation mechanisms required.
// - No worries about synchronizing with the UI thread.
// - No need to remember to undo previous UI states.
// - Microsecond performance.

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
			// Call update_view() any where in your
			// business logic to change views.
			w.update_view(main_view)
		}
	)
	window.run()
}

// The view generator set in update_view() is called on
// every user event (mouse move, click, resize, etc.).
fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[App]()

	return gui.column(
		width:    w
		height:   h
		h_align:  .center
		v_align:  .middle
		sizing:   gui.fixed_fixed
		content: [
			gui.text(text: 'Welcome to GUI'),
			gui.button(
				text:     '${app.clicks} Clicks'
				on_click: fn (_ &gui.ButtonCfg, e &gg.Event, mut w gui.Window) bool {
					mut app := w.state[App]()
					app.clicks += 1
					return true // true says click was handled
				}
			),
		]
	)
}
```

![screen shot](gui.png)

## Description

GUI is a flex-box style UI framework written in [V](https://vlang.io),
with declarative syntax and microsecond performance. It aspires to be a
useful framework with a short a learning curve.

## Roadmap

I plan to create a capable, robust and fairly complete UI framework. As
to timelines, who knows. I'm making this up as I go along. Currently,
this is the only project I'm working on, so expect frequent updates.
