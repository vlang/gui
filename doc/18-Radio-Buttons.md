### 18 Radio

A radio button is a graphical control element that allows the user to choose
only one of a predefined set of mutually exclusive options. The `radio` view
provides this functionality, displaying a circular button that can be either
selected or unselected, accompanied by a text label.

```v
import gui

pub fn radio(cfg gui.RadioCfg) gui.View
```

The `radio` function creates a new radio button view based on the provided
configuration.

#### RadioCfg

The `RadioCfg` struct holds the configuration for a radio button.

| Field            | Type                                  | Description                                            |
| ---------------- | ------------------------------------- | ------------------------------------------------------ |
| `id`             | `string`                              | The unique identifier for the radio view.              |
| `label`          | `string`                              | The text label displayed next to the radio button.     |
| `color`          | `Color`                               | The border color of the radio button.                  |
| `color_hover`    | `Color`                               | The border color when the mouse is hovering over it.   |
| `color_focus`    | `Color`                               | The border color when the radio button has focus.      |
| `color_border`   | `Color`                               | The border color of the radio button circle.           |
| `color_select`   | `Color`                               | The color of the inner circle when selected.           |
| `color_unselect` | `Color`                               | The color of the inner circle when not selected.       |
| `padding`        | `Padding`                             | The padding around the radio button.                   |
| `text_style`     | `TextStyle`                           | The style for the label's text.                        |
| `on_click`       | `fn (&Layout, mut Event, mut Window)` | **Required.** The callback function for a click event. |
| `size`           | `f32`                                 | The diameter of the radio button circle.               |
| `id_focus`       | `u32`                                 | The focus identifier for the radio button.             |
| `disabled`       | `bool`                                | If `true`, the radio button is disabled.               |
| `select`         | `bool`                                | If `true`, the radio button is in a selected state.    |
| `invisible`      | `bool`                                | If `true`, the radio button will not be visible.       |

#### Example

Here is an example of how to create a group of radio buttons where only one
option can be selected at a time.

```v
import gui

@[heap]
struct App {
mut:
	selected_option string = 'Option 2'
}

fn main() {
	mut window := gui.window(
		width:   300
		height:  180
		title:   'Radio Button Example'
		state:   &App{}
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[App]()
	options := ['Option 1', 'Option 2', 'Option 3']

	mut radio_buttons := []gui.View{}
	radio_buttons << gui.text(text: 'Choose an option:')
	for option in options {
		radio_buttons << gui.radio(
			label:    option
			select:   app.selected_option == option
			on_click: fn [option] (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
				mut app := w.state[App]()
				app.selected_option = option
			}
		)
	}

	return gui.column(
		width:   w
		height:  h
		spacing: 10
		content: radio_buttons
	)
}
```