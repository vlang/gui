module gui

pub struct ListBoxCfg {
pub:
	id             string
	id_scroll      u32
	selected       []string
	multiple       bool
	fill           bool    = true
	fill_border    bool    = true
	color          Color   = gui_theme.color_interior
	color_border   Color   = gui_theme.color_border
	padding        Padding = gui_theme.padding_medium
	padding_border Padding = padding_one
	sizing         Sizing
	data           []ListBoxOption
	on_select      fn (value []string, mut e Event, mut w Window) = unsafe { nil }
}

pub struct ListBoxOption {
pub:
	name  string
	value string
}

pub fn list_box(cfg ListBoxCfg) View {
	mut list := []View{}

	for dat in cfg.data {
		color := if dat.value in cfg.selected { gui_theme.color_select } else { color_transparent }
		list << row(
			color:    color
			fill:     true
			padding:  padding_two_five
			sizing:   fill_fit
			content:  [
				text(
					text: dat.name
					mode: .multiline
				),
			]
			on_click: fn [cfg, dat] (_ voidptr, mut e Event, mut w Window) {
				if cfg.on_select != unsafe { nil } {
					mut values := cfg.selected.clone()
					if !cfg.multiple {
						values.clear()
					}
					match dat.value in cfg.selected {
						true { values = values.filter(it != dat.value) }
						else { values << dat.value }
					}
					cfg.on_select(values, mut e, mut w)
				}
			}
			on_hover: fn [cfg] (mut node Layout, mut e Event, mut w Window) {
				if cfg.on_select != unsafe { nil } {
					w.set_mouse_cursor_pointing_hand()
					if node.shape.color == color_transparent {
						node.shape.fill = true
						node.shape.color = gui_theme.color_hover
					}
				}
			}
		)
	}

	return column( // border
		color:   cfg.color_border
		fill:    cfg.fill_border
		padding: cfg.padding_border
		sizing:  cfg.sizing
		content: [
			column( // interior
				id_scroll:       cfg.id_scroll
				scrollbar_cfg_y: ScrollbarCfg{
					offset_x: -1
				}
				color:           cfg.color
				fill:            cfg.fill
				padding:         cfg.padding
				sizing:          cfg.sizing
				spacing:         0
				content:         list
			),
		]
	)
}

pub fn list_box_option(name string, value string) ListBoxOption {
	return ListBoxOption{
		name:  name
		value: value
	}
}
