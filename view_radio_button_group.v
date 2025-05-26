module gui

// RadioButtonGroupCfg configures a [radio_button_group](#radio_button_group_column).
// If title is empty, the visible renctangle around the button group is invisible.
// If the id_focus is in the [RadioOption](#RadioOption) is zero, no focus is not rendered.
// The `on_select` is where the app model is updated.
//
// Example:
// ```v
// gui.radio_button_group(
// 	title:     'City Group'
// 	value:     app.selected_value
// 	options:   [
// 		gui.radio_option('New York', 'ny', 1), // label, value, id_focus
// 		gui.radio_option('Detroit', 'dtw', 2),
// 		gui.radio_option('Chicago', 'chi', 3),
// 		gui.radio_option('Los Angeles', 'la', 4),
// 	]
// 	on_select: fn [mut app] (value string) {
// 		app.selected_value = value
// 	}
// 	window:    window
// )
// ```
pub struct RadioButtonGroupCfg {
pub:
	title     string
	options   []RadioOption
	value     string
	id_focus  u32
	on_select fn (string) @[required]
	window    &Window
}

// RadioOption defines a radio button for a [RadioButtonGroupCfg](#RadioButtonGroupCfg)
pub struct RadioOption {
pub:
	name  string
	value string
}

// radio_option is a helper function to create a [RadioOption](#RadioOption)
pub fn radio_option(name string, value string) RadioOption {
	return RadioOption{
		name:  name
		value: value
	}
}

// radio_button_group_column creates a vertically stacked radio button group from
// the given [RadioButtonGroupCfg](#RadioButtonGroupCfg)
pub fn radio_button_group_column(cfg RadioButtonGroupCfg) View {
	return column(
		text:    cfg.title
		color:   if cfg.title.len == 0 { color_transparent } else { gui_theme.color_5 }
		padding: if cfg.title.len == 0 { gui_theme.padding_medium } else { gui_theme.padding_large }
		content: build_options(cfg)
	)
}

// radio_button_group_row creates a horizontally stacked radio button group from
// the given [RadioButtonGroupCfg](#RadioButtonGroupCfg)
pub fn radio_button_group_row(cfg RadioButtonGroupCfg) View {
	return row(
		text:    cfg.title
		color:   if cfg.title.len == 0 { color_transparent } else { gui_theme.color_5 }
		padding: if cfg.title.len == 0 { gui_theme.padding_medium } else { gui_theme.padding_large }
		content: build_options(cfg)
	)
}

fn build_options(cfg RadioButtonGroupCfg) []View {
	mut content := []View{}
	mut id_focus := cfg.id_focus
	for option in cfg.options {
		content << radio_label(option.name, option.value, cfg.value, id_focus, cfg.on_select,
			cfg.window)
		if cfg.id_focus != 0 {
			id_focus += 1
		}
	}
	return content
}

fn radio_label(label string, value string, selected_value string, id_focus u32, on_select fn (id string), w &Window) View {
	return row(
		radius:   0
		id_focus: id_focus
		color:    if w.is_focus(id_focus) { theme().color_5 } else { color_transparent }
		padding:  padding_two_five
		on_click: fn [value, on_select] (_ voidptr, mut _e Event, mut w Window) {
			on_select(value)
		}
		on_char:  fn [value, on_select] (_ voidptr, mut e Event, mut w Window) {
			if e.char_code == ` ` {
				on_select(value)
			}
		}
		on_hover: fn (mut node Layout, mut _ Event, mut w Window) {
			w.set_mouse_cursor_pointing_hand()
		}
		content:  [
			radio(selected: selected_value == value),
			text(text: label),
		]
	)
}
