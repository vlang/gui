# 17 Pulsar

The `pulsar` module provides a simple, animated view that can be used to
indicate activity or a loading state.

## `pulsar(cfg PulsarCfg) View`

The `pulsar` function creates a view that displays a blinking icon. The
animation works by alternating between two different icons.

**Note:** For the blinking animation to be active, the `window.cursor_blink`
property must be set to `true`.

### Usage

Here is a basic example of how to use the `pulsar` view:

```v
import gui

fn main() {
	mut window := gui.window(
		title:        'Pulsars'
		width:        400
		height:       200
		cursor_blink: true // pulsars require the cursor animation
		on_init:      fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
		content: [
			gui.text(
				text:       'Pulsars blink to get attention!'
				text_style: gui.theme().b1
			),
			window.pulsar(),
		]
	)
}
```

## `PulsarCfg`

This struct is used to configure the `pulsar` view.

| Field   | Type     | Default Value                    | Description                                                                 |
| ------- | -------- | -------------------------------- | --------------------------------------------------------------------------- |
| `id`    | `string` |                                  | A unique identifier for the view.                                           |
| `icon1` | `string` | `icon_elipsis_h`                 | The first icon to display. Also used to calculate the view's minimum width. |
| `icon2` | `string` | `icon_elipsis_v`                 | The second icon to display in the animation cycle.                          |
| `color` | `Color`  | `gui_theme.text_style.color`     | The color of the icon.                                                      |
| `size`  | `u32`    | `gui_theme.size_text_medium`     | The font size of the icon.                                                  |
| `width` | `f32`    | `get_text_width_no_cache(icon1)` | The width of the pulsar. Defaults to the width of the icon.                 |