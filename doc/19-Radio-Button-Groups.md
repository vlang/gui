# 19 Radio Button Group

The `radio_button_group` view provides a convenient way to manage a collection
of radio buttons where only one option can be selected at a time. It simplifies
the creation and management of mutually exclusive choices.

```v
import gui

pub fn radio_button_group(cfg gui.RadioButtonGroupCfg) gui.View
```

The `radio_button_group` function creates a view that contains multiple radio
buttons, ensuring that only one is active at any given time.

## `RadioButtonGroupCfg`

This struct configures the `radio_button_group` view.

| Field       | Type                                 | Description                          |
| ----------- | ------------------------------------ | ------------------------------------ |
| `id`        | `string`                             | Unique identifier.                   |
| `options`   | `[]string`                           | List of labels for buttons.          |
| `selected`  | `string`                             | The currently selected option.       |
| `on_select` | `fn (string, mut Event, mut Window)` | Callback when an option is chosen.   |
| `spacing`   | `f32`                                | Vertical space between buttons.      |
| `disabled`  | `bool`                               | If `true`, all buttons are disabled. |
| `invisible` | `bool`                               | If `true`, the group is not visible. |

## Example

Here is an example of how to use the `radio_button_group` to allow the user to
select a preferred color.

```v
import gui

@[heap]
struct RadioButtonGroupApp {
pub mut:
	select_value string = 'ny'
}

fn main() {
	mut window := gui.window(
		title:   'Radio Button Groups'
		state:   &RadioButtonGroupApp{}
		width:   600
		height:  400
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
			w.set_id_focus(1)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	mut app := window.state[RadioButtonGroupApp]()

	options := [
		gui.radio_option('New York', 'ny'), // label, value,
		gui.radio_option('Detroit', 'dtw'),
		gui.radio_option('Chicago', 'chi'),
		gui.radio_option('Los Angeles', 'la'),
	]

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		spacing: gui.theme().spacing_large
		content: [
			gui.radio_button_group_row(
				title:     'City Group'
				value:     app.select_value
				options:   options
				id_focus:  100
				on_select: fn [mut app] (value string, mut _ gui.Window) {
					app.select_value = value
				}
			),
			// Intentionally using the same data/focus id to show vertical
			// and horizontal side-by-side
			gui.radio_button_group_column(
				title:     'City Group'
				value:     app.select_value
				options:   options
				id_focus:  100
				on_select: fn [mut app] (value string, mut _ gui.Window) {
					app.select_value = value
				}
			),
		]
	)
}
```

## See Also

- `18-Radio-Buttons.md` --- Details on individual radio buttons.
- `04-Rows-Columns.md` --- How `column` is used for layout.
- `05-Themes-Styles.md` --- Styling options for radio buttons.