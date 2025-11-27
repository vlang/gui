# 2 Getting Started

GUI is a flex-box-like layout system. Instead of specifying x, y, width,
and height coordinates, views are specified relative to each other and
have instructions that specify if the item should fit or fill to the
contents, etc. This allows layouts to be fluid and adapt to the size of
the window while looking similar on high or low dpi displays.

When dimensions are required, v-gui uses, "logical pixels" instead of
physical pixels. Logical pixels are small, on the order of the size of a
physical pixel. When v-gui draws to the screen it scales and translates
logical pixels to appear on the display consistently, preserving aspect
ratios (circles appear as circles and not ellipes for instance).

Starting simple, the following example displays a window with centered
text and a button that counts clicks.

```v
import gui

// v-gui uses a view generator (a function that returns a View) to
// render the contents of the Window. As the state of the app
// changes, either through user actions or business logic, GUI
// calls the view generator to build a new view. The new view is
// used to render the contents of the window.
//
// There are several advantages to this approach.
// - The view is simply a function of the model (state).
// - No data binding or other observation mechanisms are required.
// - No worries about synchronizing with the UI thread.
// - No need to remember to undo previous UI states.

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
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
		content: [
			gui.text(
				text:       'Welcome to GUI'
				text_style: gui.theme().b1
			),
			gui.button(
				id_focus:       1
				padding_border: gui.padding_two
				content:        [gui.text(text: '${app.clicks} Clicks')]
				on_click:       fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[App]()
					app.clicks += 1
				}
			),
		]
	)
}
```

If you have developed flex-box layout UI's before, most of this should
feel familiar.

Let's take it in parts.

```v
import gui
```

This imports the `gui` library.

``` v
struct App {
pub mut:
	clicks int
}
```

This is the application model. Most applications will have some type of
data model. The state of the application is stored here. State should
not be stored in views.

``` v
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
```

As shown, a window is created. Notice that the app state is stored in
the window. This is important as we'll see in a moment. The other
interesting bit is the `on_init` function. v-gui calls this function when
the window is initialized. This is where the application's view is first
set. Different views can be shown but calling `update_window` anytime
with a different view. Let's look at the `main_view` in two sections.
Here is the top portion.

``` v
import gui

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[App]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
	...
```

`main_view` is a function that generates a view. Since it is the main
view, it is good practice to size the first view (a column) to the
window size. The two fundamental layout views are `row` and `column`.
`row` and `column` stack their content left-to-right and top-to-bottom
accordingly.

This is a good time to discuss one of the unique aspects of v-gui,
immediate mode. Immediate mode means that whenever the view is updated,
the entire view is redrawn. This is similar to how many Web UI
frameworks work (e.g. React). The advantage of immediate mode is that
the programmer does not have to remember to undraw parts of the view. A
classic example is a tab view. Most UI's will highlight the currently
viewed tab. When a different tab is selected, the old tab is
unhighlighted and the new tab is highlighted. Forget to unhighlight the
tab and the UI will appear confusing to the user. In immediate mode,
since the entire view is redrawn, there is no need to undo the
previously highlighted tab.

v-gui interfaces can be redrawn many times per second depending on user
interaction. For instance, clicking a button for instance will call
`main_view` to generate a new view. Don't worry, v-gui can update a view
on the order of microseconds (not milliseconds, microseconds).

Remember the app state we gave the Window? It is always available from
the Window by calling `window.state[App]()`.

In the second part of `main_view`, the fun stuff happens. Drawing text
and buttons.

```
	content: [
		gui.text(
			text:       'Welcome to GUI'
			text_style: gui.theme().b1
		),
		gui.button(
			id_focus:       1
			padding_border: gui.padding_two
			content:        [gui.text(text: '${app.clicks} Clicks')]
			on_click:       fn (_ &gui.ButtonCfg, mut _ gui.Event, mut w gui.Window) {
				mut app := w.state[App]()
				app.clicks += 1
			}
		),
	]
```

There's a bit to unpack here.

`gui.text` displays text of course. The `text_style` defines the font,
size, and weight of the text. v-gui has a theming system like other UI
frameworks. For convienence, v-gui defines several predefined selections.
They are:

- `n1,n2,n3,n4,n5,n6`, normal text_style
- `b1,b2,b3,b4,b5,b6`, bold text_style
- `i1,i2,i3,i4,i5,i6`, italic text_style
- `m1,m2,m3,m4,m5,m6`, monospace text_style

The numbers indicate the size with 1 being the largest and 6 being the
smallest. The 3 size can be thought of as the medium or default size. If
no text_style is given to the text view, it defaults to `n3`.

`gui.button` not surprisingly, creates a button. When a button is
clicked, the `on_click` callback is called. The application's state is
retrieved and the click count is updated. v-gui will automatically call
`main_view` when the click event completes. The new view is created with
the updated click count.

Notice, that `gui.button` is a container. Buttons are not limited to
text and can contain other views. See `buttons.v` for an example of a
button with a progress bar.

`id_focus` is required if the button needs to respond to keyboard input
(space bar), Focus management is discussed in a later chapter, but a
quick summary goes as follows. `id_focus` is a number greater than zero.
If multiple views have an `id_focus`, the order of numbers determines
the tabbing order of the views.

`padding_border` has the name implies, indicates how thick the button
border is. In general, most views have padding. Padding is the amount of
space, in logical pixels around the view. Padding has a top,right,bottom
and left setting. `padding_two` is a convenience method that sets the
padding as `Padding{2, 2, 2, 2}`. Button also has an inner padding
setting named `padding`. The default theme defaults to a padding of 0
for borders and a padding of 5 for other views.

As mentioned earlier, v-gui supports themes that will be discussed in a
later chapter. To quickly summarize, v-gui has 4 default themes.
'dark`,`light`,`dark-no-padding`and`light-no-padding\`. It is as easy as
calling "window.set_theme(gui.light_theme)" to change to a brighter
theme.

Finally, there's resizing the window. What happens when the window is
resized? You probably guessed already, it calls `main_view` and
generates a new view.