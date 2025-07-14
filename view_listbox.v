module gui

// ListBoxCfg configures a [list_box](#list_box) view.
// `selected` is a the list of selected `values`
pub struct ListBoxCfg {
pub:
	id               string
	id_scroll        u32
	selected         []string // list of selected values. Not names
	multiple         bool     // allow multiple selections
	width            f32
	height           f32
	min_width        f32
	max_width        f32
	min_height       f32
	max_height       f32
	color            Color   = gui_theme.list_box_style.color
	color_hover      Color   = gui_theme.list_box_style.color_hover
	color_border     Color   = gui_theme.list_box_style.color_border
	color_select     Color   = gui_theme.list_box_style.color_select
	fill             bool    = gui_theme.list_box_style.fill
	fill_border      bool    = gui_theme.list_box_style.fill_border
	padding          Padding = gui_theme.list_box_style.padding
	padding_border   Padding = gui_theme.list_box_style.padding_border
	radius           f32     = gui_theme.list_box_style.radius
	radius_border    f32     = gui_theme.list_box_style.radius_border
	sizing           Sizing
	text_style       TextStyle = gui_theme.list_box_style.text_style
	subheading_style TextStyle = gui_theme.list_box_style.subheading_style
	data             []ListBoxOption
	on_select        fn (value []string, mut e Event, mut w Window) = unsafe { nil }
}

// ListBoxOption is the data for a row in a [list_box](#list_box).
// See [list_box_option](#list_box_option) helper method
pub struct ListBoxOption {
pub:
	name  string
	value string
}

// list_box is a convenience view for simple cases. See [ListBoxCfg](#ListBoxCfg)
// The same functionality can be done with a column and rows.
// In fact, the implementation is not much more than that.
pub fn list_box(cfg ListBoxCfg) &View {
	mut list := []&View{}

	for dat in cfg.data {
		color := if dat.value in cfg.selected { gui_theme.color_select } else { color_transparent }
		is_subheader := dat.name.starts_with('---')
		mut content := []&View{}

		if is_subheader {
			content << column(
				spacing: 1
				padding: padding_none
				sizing:  fill_fit
				content: [
					text(
						text:       dat.name[3..]
						text_style: cfg.subheading_style
					),
					row(
						padding: padding_none
						sizing:  fill_fit
						content: [
							rectangle(
								width:  1
								height: 1
								sizing: fill_fit
								color:  cfg.subheading_style.color
							),
						]
					),
				]
			)
		} else { // normal option
			content << text(
				text:       dat.name
				mode:       .multiline
				text_style: cfg.text_style
			)
		}

		list << row(
			name:     'list_box option'
			color:    color
			fill:     true
			padding:  padding_two_five
			sizing:   fill_fit
			content:  content
			on_click: fn [cfg, dat, is_subheader] (_ voidptr, mut e Event, mut w Window) {
				if cfg.on_select != unsafe { nil } && !is_subheader {
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
			on_hover: fn [cfg, is_subheader] (mut node Layout, mut e Event, mut w Window) {
				if cfg.on_select != unsafe { nil } && !is_subheader {
					w.set_mouse_cursor_pointing_hand()
					if node.shape.color == color_transparent {
						node.shape.fill = true
						node.shape.color = cfg.color_hover
					}
				}
			}
		)
	}

	return column(
		name:       'list_box border'
		width:      cfg.max_width
		height:     cfg.height
		min_width:  cfg.min_width
		max_width:  cfg.max_width
		min_height: cfg.min_height
		max_height: cfg.max_height
		color:      cfg.color_border
		fill:       cfg.fill_border
		padding:    cfg.padding_border
		sizing:     cfg.sizing
		cfg:        &cfg
		content:    [
			column(
				name:            'list_box interior'
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

// list_box_option is a helper method to construct [ListBoxOption](#ListBoxOption).
// It can allow specifying a option on a single line whereas the struct version
// is always formatted to multiple lines.
//
// If an option name starts with `---` it is treated as is_subheader
// The three leading hyphens are dropped and the the rest of the name
// is displayed using the subheader style. A horizontal bar is drawn
// below the subheader.
pub fn list_box_option(name string, value string) ListBoxOption {
	return ListBoxOption{
		name:  name
		value: value
	}
}
