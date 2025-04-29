module gui

// ScrollbarCfg configures the style of a scrollbar. Column and Row
// define a default ScrollbarCfg so most of the time it is only
// need to define scrollbar: true in the Column/Row config.
// Scrollbars are optional. Columns/Rows are scrollable without them.
// See examples/column-scroll.v for a scrolling with a scrollbar and
// examples/scroll-demo.v for one without out.
@[heap]
pub struct ScrollbarCfg {
pub:
	id               string
	id_track         u32
	width            f32     = gui_theme.scrollbar_style.width
	color_thumb      Color   = gui_theme.scrollbar_style.color_thumb
	color_gutter     Color   = gui_theme.scrollbar_style.color_gutter
	color_background Color   = gui_theme.scrollbar_style.color_background
	fill_thumb       bool    = gui_theme.scrollbar_style.fill_thumb
	fill_gutter      bool    = gui_theme.scrollbar_style.fill_gutter
	fill_background  bool    = gui_theme.scrollbar_style.fill_background
	radius           f32     = gui_theme.scrollbar_style.radius
	padding          Padding = gui_theme.scrollbar_style.padding
}

// scrollbar creates a scrollbar. Scrollbars are floating elements
// which allows for a suprising number of styling an layout options.
pub fn scrollbar(cfg ScrollbarCfg) View {
	return column(
		id:            cfg.id
		width:         cfg.width
		fill:          cfg.fill_background
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
		fill:     cfg.fill_thumb
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
		fill:    cfg.fill_gutter
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
		// add 10 to give some cushion on the ends of the scroll range
		if e.mouse_y >= (n.shape.y - 10) && e.mouse_y <= (n.shape.y + n.shape.height + 10) {
			offset := offset_from_mouse_change(n, e.mouse_dy, cfg.id_track, w)
			w.scroll_state[cfg.id_track] = offset
		}
	}
}

fn (cfg &ScrollbarCfg) mouse_up(node &Layout, mut e Event, mut w Window) {
	w.mouse_unlock()
}

// Don't know what the sizes and positions of the scrollbar elements should
// be until after the layout is almost done requiring manual layout here.
// Scrollbars are hard.
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
	offset := f32_max(0, f32_min((scroll_offset / (total_height - parent.shape.height)) * available_height,
		available_height))

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

	// on hover dim color of thumb
	ctx := w.context()
	if node.shape.point_in_shape(f32(ctx.mouse_pos_x), f32(ctx.mouse_pos_y)) || w.mouse_is_locked() {
		if w.dialog_cfg.visible && !node_in_dialog_layout(node) {
			return
		}
		node.children[thumb].shape.color = gui_theme.button_style.color_hover
	}
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

fn offset_from_mouse_change(node Layout, mouse_y f32, id_scroll u32, w &Window) f32 {
	total_height := content_height(node)
	old_offset := w.scroll_state[id_scroll]
	new_offset := mouse_y * (total_height / node.shape.height)
	offset := old_offset - new_offset
	return f32_min(0, f32_max(offset, node.shape.height - node.shape.padding.height() - total_height))
}
