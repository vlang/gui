module gui

pub struct ScrollbarCfg {
pub:
	id           string
	id_track     u32
	width        f32     = 10
	color_thumb  Color   = gui_theme.color_5
	color_gutter Color   = color_transparent
	padding      Padding = padding_none
}

pub fn scrollbar(cfg ScrollbarCfg) View {
	return column(
		id:            cfg.id
		width:         cfg.width
		float:         true
		float_anchor:  .top_right
		float_tie_off: .top_right
		sizing:        fit_fill
		spacing:       0
		padding:       cfg.padding
		amend_layout:  cfg.amend_layout
		content:       [
			gutter(cfg, '__top_gutter__'),
			thumb(cfg),
			gutter(cfg, '__bottom_gutter__'),
		]
	)
}

fn thumb(cfg ScrollbarCfg) View {
	return column(
		id:      '__thumb__'
		width:   cfg.width
		fill:    true
		spacing: 0
		color:   cfg.color_thumb
		padding: padding_none
	)
}

fn gutter(cfg ScrollbarCfg, id string) View {
	return column(
		id:      id
		width:   cfg.width
		height:  0
		fill:    false
		spacing: 0
		color:   cfg.color_gutter
		padding: padding_none
	)
}

fn (cfg ScrollbarCfg) amend_layout(mut node Layout, mut w Window) {
	mut parent := node.parent
	for {
		if parent == unsafe { nil } {
			return
		}
		if parent.shape.id_scroll == cfg.id_track {
			break
		}
		parent = parent.parent
	}
	total_height := content_height(parent)
	t_height := parent.shape.height * (parent.shape.height / total_height)
	thumb_height := f32_min(f32_max(20, t_height), parent.shape.height)
	available_height := parent.shape.height - thumb_height
	scroll_offset := -w.scroll_state[cfg.id_track]
	offset := f32_min((scroll_offset / (total_height - parent.shape.height)) * available_height,
		available_height)

	top_gutter := 0
	y := node.children[top_gutter].shape.y
	node.children[top_gutter].shape.height = offset

	thumb := 1
	node.children[thumb].shape.y = y + offset
	node.children[thumb].shape.height = thumb_height

	bottom_gutter := 2
	node.children[bottom_gutter].shape.y = y + offset + thumb_height
	node.children[bottom_gutter].shape.height = parent.shape.height - offset - thumb_height
}
