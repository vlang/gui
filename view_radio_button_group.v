module gui

// RadioButtonGroupCfg configures a [radio_button_group](#radio_button_group_column).
// If title is empty, the visible renctangle around the button group is invisible.
// If the id_focus is in the [RadioOption](#RadioOption) is zero, no focus is not rendered.
// The `on_select` is where the app model is updated.
//
// Example:
// ```v
// gui.radio_button_group_column(
// 	title:     'City Group'
// 	value:     app.select_city
// 	options:   [
// 		gui.radio_option('New York', 'ny'),
// 		gui.radio_option('Detroit', 'dtw'),
// 		gui.radio_option('Chicago', 'chi'),
// 		gui.radio_option('Los Angeles', 'la'),

// 	on_select: fn [mut app] (value string) {
// 		app.select_city = value
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
	label string
	value string
}

// radio_option is a helper function to create a [RadioOption](#RadioOption)
pub fn radio_option(label string, value string) RadioOption {
	return RadioOption{
		label: label
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
		content << radio(
			label:    option.label
			id_focus: id_focus
			selected: cfg.value == option.value
			on_click: fn [cfg, option] (_ voidptr, mut _e Event, mut w Window) {
				cfg.on_select(option.value)
			}
		)
		if cfg.id_focus != 0 {
			id_focus += 1
		}
	}
	return content
}
