module gui

import math

@[heap]
pub struct ScrollbarCfg {
pub:
	id           string
	id_track     u32 // id_scroll to track
	width        f32     = 8
	color_thumb  Color   = gui_theme.color_5
	color_gutter Color   = color_transparent
	padding      Padding = padding_two
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
			gutter(cfg, '__top_gutter__${cfg.id_track}'),
			thumb(cfg, '__thumb__${cfg.id_track}'),
			gutter(cfg, '__bottom_gutter__${cfg.id_track}'),
		]
	)
}

fn thumb(cfg &ScrollbarCfg, id string) View {
	return column(
		id:       id
		width:    cfg.width
		fill:     true
		spacing:  0
		color:    cfg.color_thumb
		padding:  padding_none
		on_click: cfg.on_mouse_down
	)
}

fn gutter(cfg &ScrollbarCfg, id string) View {
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

fn (cfg &ScrollbarCfg) on_mouse_down(_ voidptr, mut e Event, mut w Window) {
	w.mouse_lock(MouseLockCfg{
		mouse_move: cfg.mouse_move
		mouse_up:   cfg.mouse_up
	})
}

fn (cfg &ScrollbarCfg) mouse_move(node &Layout, mut e Event, mut w Window) {
	if n := find_node_by_id_scroll(node, cfg.id_track) {
		if thumb := find_scrollbar_thumb(node, cfg.id_track) {
			offset := offset_from_mouse(n, thumb, e.mouse_y, cfg.id_track)
			w.scroll_state[cfg.id_track] = offset
		}
	}
}

fn (cfg &ScrollbarCfg) mouse_up(node &Layout, mut e Event, mut w Window) {
	w.mouse_unlock()
}

fn (cfg &ScrollbarCfg) amend_layout(mut node Layout, mut w Window) {
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
	node.shape.height = parent.shape.height
	total_height := content_height(parent)
	t_height := parent.shape.height * (parent.shape.height / total_height)
	thumb_height := f32_min(f32_max(20, t_height), parent.shape.height)
	available_height := parent.shape.height - thumb_height - cfg.padding.height()
	scroll_offset := -w.scroll_state[cfg.id_track]
	offset := f32_min((scroll_offset / (total_height - parent.shape.height)) * available_height,
		available_height)

	top_gutter := 0
	mut y := node.children[top_gutter].shape.y
	node.children[top_gutter].shape.height = offset - 1

	y += offset

	thumb := 1
	node.children[thumb].shape.y = y
	node.children[thumb].shape.height = thumb_height - 1

	y += thumb_height

	bottom_gutter := 2
	node.children[bottom_gutter].shape.y = y
	node.children[bottom_gutter].shape.height = parent.shape.height - offset - thumb_height - node.shape.padding.height()
}

fn find_node_by_id_scroll(node Layout, id_scroll u32) ?Layout {
	if node.shape.id_scroll == id_scroll {
		return node
	}
	for child in node.children {
		if n := find_node_by_id_scroll(child, id_scroll) {
			return n
		}
	}
	return none
}

fn find_scrollbar_thumb(node Layout, id_scroll u32) ?Shape {
	if node.shape.id == '__thumb__${id_scroll}' {
		return node.shape
	}
	for child in node.children {
		if n := find_scrollbar_thumb(child, id_scroll) {
			return n
		}
	}
	return none
}

fn offset_from_mouse(node Layout, thumb Shape, mouse_y f32, id_scroll u32) f32 {
	available_height := node.shape.height - thumb.height
	mut th := mouse_y - thumb.y
	th = f32_min(math.abs(th), thumb.height)
	mut percent := (node.shape.y - mouse_y + th) / available_height
	if percent >= 0 {
		percent = 0
	}
	if percent <= -1.0 {
		percent = -1.0
	}
	total_height := content_height(node)
	return percent * (total_height - node.shape.height + node.shape.padding.height())
}
