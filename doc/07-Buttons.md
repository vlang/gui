# 7 Buttons

Buttons are clickable containers. In v-gui, a button is a `row` (the
border) that contains another `row` (the button body) that can hold any
views (commonly `text`, but it can be icons, images, progress bars,
etc.).

A button will only respond to mouse/keyboard interactions when an
`on_click` handler is provided. Without `on_click`, it renders visually
but behaves like static “bubble text” (no interaction).

See also: `examples/buttons.v` for a runnable showcase.

## Button configuration

The `button` view is created with a `ButtonCfg` structure. Important
fields:

- `id string` — Optional identifier for the view row (useful for
  tooling).
- `tooltip &TooltipCfg` — Optional tooltip configuration.
- Colors
  - `color` — Normal interior color
  - `color_hover` — Interior color while hovered
  - `color_focus` — Interior color while focused
  - `color_click` — Interior color while mouse button is down
  - `color_border` — Border color
  - `color_border_focus` — Border color while focused
- Padding and radius
  - `padding Padding` — Interior padding (inside the button body)
  - `padding_border Padding` — Border padding (space around the body)
  - `radius f32` — Corner radius for interior
  - `radius_border f32` — Corner radius for border
- Sizing and layout
  - `sizing Sizing` — Standard sizing (`fit`, `fill`, `fixed`,
    combinations)
  - `width/height/min_width/min_height/max_width/max_height f32` —
    Bounds
  - `h_align HorizontalAlign` — Content horizontal alignment (default
    `.center`)
  - `v_align VerticalAlign` — Content vertical alignment (default
    `.middle`)
  - `fill bool` — Fill interior rectangle
  - `fill_border bool` — Fill border rectangle (use `false` for a
    detached border)
- Interaction and state
  - `on_click fn (&Layoyut, mut Event, mut Window)` — Click handler
    (required for interactivity)
  - `id_focus u32` — Focus-group id (used by keyboard focus)
  - `disabled bool` — When `true`, button won’t accept input
  - `invisible bool` — When `true`, removes from layout/paint
- Content
  - `content []View` — Arbitrary child views (e.g., `text`, `image`,
    `progress_bar`, etc.)

## Interaction model

- Hover: when the pointer is over a clickable button, the mouse cursor
  changes to a pointing hand and the interior color switches to
  `color_hover`.
- Press: while the left mouse button is down, the interior uses
  `color_click`.
- Focus: when focused, interior uses `color_focus`, and border uses
  `color_border_focus`.
- Keyboard activation: Space (`' '`) triggers `on_click` when the button
  is focusable and has a click handler.
- Non-interactive mode: if `on_click` is `nil`, hover/focus/click
  visuals and pointer cursor are disabled.

## Basic example (counter button)

A minimal clickable button that increments a counter stored in window
state:

```v
import gui

struct App {
mut:
	clicks int
}

fn main() {
	mut window := gui.window(
		title:   'Counter Button'
		state:   &App{}
		width:   300
		height:  150
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
			// Optional: set initial keyboard focus
			w.set_id_focus(1)
		}
	)
	window.run()
}

fn main_view(mut w gui.Window) gui.View {
	a := w.state[App]()
	btn_text := '${a.clicks} Clicks'

	return gui.column(
		padding: gui.theme().padding_medium
		h_align: .center
		v_align: .middle
		content: [
			gui.button(
				id_focus:  1
				min_width: 120
				max_width: 120
				content:   [gui.text(text: btn_text)]
				on_click:  fn (_ &gui.Layout, mut _ gui.Event, mut win gui.Window) {
					mut app := win.state[App]()
					app.clicks++
				}
			),
		]
	)
}
```

## Variations

- Disabled button:

```v
import gui

gui.button(
	min_width: 140
	max_width: 140
	disabled:  true
	content:   [gui.text(text: 'Disabled')]
	on_click:  fn (_ &gui.Layout, mut _ gui.Event, mut _ gui.Window) {}
)
```

- With border padding (shows an outer border around the interior):

```v
import gui

gui.button(
	min_width:      140
	max_width:      140
	padding_border: gui.padding_two
	content:        [gui.text(text: 'With border')]
	on_click:       fn (_ &gui.Layout, mut _ gui.Event, mut _ gui.Window) {}
)
```

- With focusable border (set a focus id to see focused colors):

```v
import gui

gui.button(
	id_focus:       1
	min_width:      140
	max_width:      140
	padding_border: gui.padding_two
	content:        [gui.text(text: 'Focusable')]
	on_click:       fn (_ &gui.Layout, mut _ gui.Event, mut _ gui.Window) {}
)
```

- Detached border (border rectangle does not fill entire parent):

```v
import gui

gui.button(
	min_width:      140
	max_width:      140
	fill_border:    false
	padding_border: gui.theme().padding_small
	content:        [gui.text(text: 'Detached border')]
	on_click:       fn (_ &gui.Layout, mut _ gui.Event, mut _ gui.Window) {}
)
```

- Custom content (progress bar inside a button):

```v
import gui
import math

fn custom_button(app_clicks int) gui.View {
	return gui.button(
		id:             'With progress bar'
		min_width:      200
		max_width:      200
		color:          gui.rgb(195, 105, 0)
		color_hover:    gui.rgb(195, 105, 0)
		color_click:    gui.rgb(205, 115, 0)
		color_border:   gui.rgb(160, 160, 160)
		padding:        gui.padding_medium
		padding_border: gui.padding_two
		v_align:        .middle
		content:        [
			gui.text(text: '${app_clicks}', min_width: 25),
			gui.progress_bar(
				width:   75
				height:  gui.theme().text_style.size
				percent: f32(math.fmod(f64(app_clicks) / 25.0, 1.0))
			),
		]
		on_click:       fn (_ &gui.Layout, mut _ gui.Event, mut _ gui.Window) {}
	)
}
```

## Tips

- Buttons are containers: you can combine icons, text, and other views.
- To make a button purely decorative (non-interactive), omit `on_click`.
- Use `id_focus` and `w.set_id_focus(id)` to enable keyboard activation
  with Space.
- `padding` controls inner spacing; `padding_border` controls spacing
  between the outer border and the inner body.
- `fill_border: false` is handy to create a detached border appearance.

## See also

- `doc/03-Views.md` — background on views, containers, and sizing
- `examples/buttons.v` — comprehensive runnable examples