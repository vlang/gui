module gui

const list_box_virtual_buffer_rows = 2

// ListBoxCfg configures a [list_box](#list_box) view.
// `selected_ids` is a list of selected item ids.
@[minify]
pub struct ListBoxCfg {
pub:
	id               string
	sizing           Sizing
	text_style       TextStyle = gui_theme.list_box_style.text_style
	subheading_style TextStyle = gui_theme.list_box_style.subheading_style
	color            Color     = gui_theme.list_box_style.color
	color_hover      Color     = gui_theme.list_box_style.color_hover
	color_border     Color     = gui_theme.list_box_style.color_border
	color_select     Color     = gui_theme.list_box_style.color_select
	padding          Padding   = gui_theme.list_box_style.padding
	selected_ids     []string // selected item ids
	data             []ListBoxOption
	on_select        fn (ids []string, mut e Event, mut w Window) = unsafe { nil }
	width            f32
	height           f32
	min_width        f32
	max_width        f32
	min_height       f32
	max_height       f32
	radius           f32 = gui_theme.list_box_style.radius
	radius_border    f32 = gui_theme.list_box_style.radius_border
	id_scroll        u32
	multiple         bool // allow multiple selections
	size_border      f32 = gui_theme.list_box_style.size_border
}

// ListBoxOption is the data for a row in a [list_box](#list_box).
// See [list_box_option](#list_box_option) helper method.
pub struct ListBoxOption {
pub:
	id    string
	name  string
	value string
}

// list_box builds a list box without viewport virtualization.
// Use [Window.list_box](#list_box) for virtualization support.
pub fn list_box(cfg ListBoxCfg) View {
	return list_box_from_range(0, cfg.data.len - 1, cfg, false, f32(0))
}

// list_box is a convenience view for simple cases. See [ListBoxCfg](#ListBoxCfg).
// Virtualization is enabled only when `id_scroll > 0` and bounded height exists.
pub fn (mut window Window) list_box(cfg ListBoxCfg) View {
	last_row_idx := cfg.data.len - 1
	list_height := list_box_height(cfg)
	virtualize := cfg.id_scroll > 0 && list_height > 0 && cfg.data.len > 0
	row_height := if virtualize {
		list_box_estimate_row_height(cfg, mut window)
	} else {
		f32(0)
	}
	first_visible, last_visible := if virtualize {
		list_box_visible_range(list_height, row_height, cfg, mut window)
	} else {
		0, last_row_idx
	}

	return list_box_from_range(first_visible, last_visible, cfg, virtualize, row_height)
}

fn list_box_from_range(first_visible int, last_visible int, cfg ListBoxCfg, virtualize bool, row_height f32) View {
	last_row_idx := cfg.data.len - 1
	spacer_row_height := if row_height > 0 {
		row_height
	} else {
		list_box_estimate_row_height_no_window(cfg)
	}
	mut list := []View{cap: (last_visible - first_visible + 1) + 2}

	if virtualize && first_visible > 0 {
		list << rectangle(
			name:   'list_box spacer top'
			color:  color_transparent
			height: f32(first_visible) * spacer_row_height
			sizing: fill_fixed
		)
	}

	for idx in first_visible .. last_visible + 1 {
		if idx < 0 || idx >= cfg.data.len {
			continue
		}
		list << list_box_item_view(cfg.data[idx], cfg)
	}

	if virtualize && last_visible < last_row_idx {
		remaining := last_row_idx - last_visible
		list << rectangle(
			name:   'list_box spacer bottom'
			color:  color_transparent
			height: f32(remaining) * spacer_row_height
			sizing: fill_fixed
		)
	}

	return column(
		name:         'list_box'
		id_scroll:    cfg.id_scroll
		width:        cfg.max_width
		height:       cfg.height
		min_width:    cfg.min_width
		max_width:    cfg.max_width
		min_height:   cfg.min_height
		max_height:   cfg.max_height
		color:        cfg.color
		color_border: cfg.color_border
		size_border:  cfg.size_border
		radius:       cfg.radius
		padding:      cfg.padding
		sizing:       cfg.sizing
		spacing:      0
		content:      list
	)
}

fn list_box_item_view(dat ListBoxOption, cfg ListBoxCfg) View {
	color := if dat.id in cfg.selected_ids {
		cfg.color_select
	} else {
		color_transparent
	}
	is_subheader := dat.name.starts_with('---')
	mut content := []View{cap: 1}

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
	} else {
		content << text(
			text:       dat.name
			mode:       .multiline
			text_style: cfg.text_style
		)
	}

	is_multiple := cfg.multiple
	on_select := cfg.on_select
	selected_ids := cfg.selected_ids
	color_hover := cfg.color_hover

	return row(
		name:     'list_box option'
		color:    color
		padding:  padding_two_five
		sizing:   fill_fit
		content:  content
		on_click: fn [is_multiple, on_select, selected_ids, dat, is_subheader] (_ voidptr, mut e Event, mut w Window) {
			if on_select != unsafe { nil } && !is_subheader {
				mut ids := selected_ids.clone()
				if !is_multiple {
					ids.clear()
				}
				match dat.id in selected_ids {
					true { ids = ids.filter(it != dat.id) }
					else { ids << dat.id }
				}
				on_select(ids, mut e, mut w)
			}
		}
		on_hover: fn [on_select, color_hover, is_subheader] (mut layout Layout, mut e Event, mut w Window) {
			if on_select != unsafe { nil } && !is_subheader {
				w.set_mouse_cursor_pointing_hand()
				if layout.shape.color == color_transparent {
					layout.shape.color = color_hover
				}
			}
		}
	)
}

fn list_box_height(cfg ListBoxCfg) f32 {
	return if cfg.height > 0 { cfg.height } else { cfg.max_height }
}

fn list_box_estimate_row_height(cfg ListBoxCfg, mut window Window) f32 {
	text_h := list_box_font_height(cfg.text_style, mut window)
	sub_h := list_box_font_height(cfg.subheading_style, mut window)
	return f32_max(text_h, sub_h) + padding_two_five.height()
}

fn list_box_estimate_row_height_no_window(cfg ListBoxCfg) f32 {
	return f32_max(cfg.text_style.size, cfg.subheading_style.size) + padding_two_five.height()
}

fn list_box_font_height(style TextStyle, mut window Window) f32 {
	if isnil(window.text_system) {
		return style.size
	}
	vg_cfg := style.to_vglyph_cfg()
	return window.text_system.font_height(vg_cfg) or { style.size }
}

fn list_box_visible_range(list_height f32, row_height f32, cfg ListBoxCfg, mut window Window) (int, int) {
	if cfg.data.len == 0 || row_height <= 0 || list_height <= 0 {
		return 0, -1
	}
	max_idx := cfg.data.len - 1
	scroll_y := -(window.view_state.scroll_y.get(cfg.id_scroll) or { f32(0) })
	first := int_clamp(int(scroll_y / row_height), 0, max_idx)
	visible_rows := int(list_height / row_height) + 1
	mut first_visible := int_max(0, first - list_box_virtual_buffer_rows)
	last_visible := int_min(max_idx, first + visible_rows + list_box_virtual_buffer_rows)
	if first_visible > last_visible {
		first_visible = last_visible
	}
	return first_visible, last_visible
}

// list_box_option is a helper method to construct [ListBoxOption](#ListBoxOption).
// It can allow specifying an option on a single line.
pub fn list_box_option(id string, name string, value string) ListBoxOption {
	return ListBoxOption{
		id:    id
		name:  name
		value: value
	}
}

// list_box_subheading is a helper method for list box heading rows.
pub fn list_box_subheading(id string, title string) ListBoxOption {
	return ListBoxOption{
		id:    id
		name:  '---${title}'
		value: ''
	}
}
