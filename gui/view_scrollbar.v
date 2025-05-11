module gui

// ScrollbarOverflow determines how scrollbars are shown.
// Remember that to set id_scroll > 0 or these options
// have no effect.
//
// - auto shows scrollbar when required
// - hidden hides the scrollbar
// - visible always shows the scroll bar
// - on_hover show only when mouse is over scrollbar
pub enum ScrollbarOverflow {
	auto
	hidden
	visible
	on_hover
}

// ScrollbarOrientation determines the scrollbar's orientation.
// vertical is the default.
pub enum ScrollbarOrientation {
	vertical
	horizontal
}

// ScrollbarCfg configures the style of a scrollbar. Column and Row
// define a default ScrollbarCfg so most of the time it is only
// need to define id_scroll in the Column/Row config. Scrollbars are
// optional. Columns/Rows are scrollable without them (id_scroll > 0).
// See examples/column-scroll.v for a scrolling with a scrollbar and
// examples/scroll-demo.v for one without out.
@[heap]
pub struct ScrollbarCfg {
pub:
	id               string
	id_track         u32
	overflow         ScrollbarOverflow
	orientation      ScrollbarOrientation
	size             f32   = gui_theme.scrollbar_style.size
	color_thumb      Color = gui_theme.scrollbar_style.color_thumb
	color_background Color = gui_theme.scrollbar_style.color_background
	fill_thumb       bool  = gui_theme.scrollbar_style.fill_thumb
	fill_background  bool  = gui_theme.scrollbar_style.fill_background
	radius           f32   = gui_theme.scrollbar_style.radius
	radius_thumb     f32   = gui_theme.scrollbar_style.radius_thumb
	offset_x         f32   = gui_theme.scrollbar_style.offset_x // x and y are swapped in
	offset_y         f32   = gui_theme.scrollbar_style.offset_y // horizontal orientation
}

// scrollbar creates a scrollbar. Scrollbars are floating elements
// which allows for a suprising number of styling an layout options.
pub fn scrollbar(cfg ScrollbarCfg) View {
	return if cfg.orientation == .horizontal {
		row(
			id:             cfg.id
			height:         cfg.size
			fill:           cfg.fill_background
			color:          cfg.color_background
			float:          true
			float_anchor:   .bottom_left
			float_tie_off:  .bottom_left
			float_offset_x: cfg.offset_y
			float_offset_y: cfg.offset_x
			spacing:        0
			padding:        padding_none
			amend_layout:   cfg.amend_layout
			on_click:       cfg.gutter_click
			content:        [
				thumb(cfg, '__thumb__${cfg.id_track}'),
			]
		)
	} else {
		column(
			id:             cfg.id
			width:          cfg.size
			fill:           cfg.fill_background
			color:          cfg.color_background
			float:          true
			float_anchor:   .top_right
			float_tie_off:  .top_right
			float_offset_x: cfg.offset_x
			float_offset_y: cfg.offset_y
			spacing:        0
			padding:        padding_none
			amend_layout:   cfg.amend_layout
			on_click:       cfg.gutter_click
			content:        [
				thumb(cfg, '__thumb__${cfg.id_track}'),
			]
		)
	}
}

fn thumb(cfg &ScrollbarCfg, id string) View {
	return column(
		id:       id
		width:    cfg.size
		color:    cfg.color_thumb
		fill:     cfg.fill_thumb
		radius:   cfg.radius_thumb
		padding:  padding_none
		spacing:  0
		on_click: cfg.on_mouse_down
	)
}

// pass cfg by value more reliable here
fn (cfg ScrollbarCfg) on_mouse_down(_ voidptr, mut e Event, mut w Window) {
	w.mouse_lock(MouseLockCfg{
		mouse_move: cfg.mouse_move
		mouse_up:   cfg.mouse_up
	})
}

// pass cfg by value more reliable here
fn (cfg ScrollbarCfg) gutter_click(_ &ContainerCfg, mut e Event, mut w Window) {
	if !w.mouse_is_locked() {
		match cfg.orientation == .horizontal {
			true { offset_from_mouse_x(w.layout, e.mouse_x, cfg.id_track, mut w) }
			else { offset_from_mouse_y(w.layout, e.mouse_y, cfg.id_track, mut w) }
		}
	}
}

// pass cfg by value more reliable here
fn (cfg ScrollbarCfg) mouse_move(node &Layout, mut e Event, mut w Window) {
	extend := 10 // give some cushion on the ends of the scroll range
	if n := find_node_by_id_scroll(node, cfg.id_track) {
		match cfg.orientation == .horizontal {
			true {
				if e.mouse_x >= (n.shape.x - extend)
					&& e.mouse_x <= (n.shape.x + n.shape.width + extend) {
					offset := offset_mouse_change_x(n, e.mouse_dx, cfg.id_track, w)
					w.view_state.offset_x_state[cfg.id_track] = offset
				}
			}
			else {
				if e.mouse_y >= (n.shape.y - extend)
					&& e.mouse_y <= (n.shape.y + n.shape.height + extend) {
					offset := offset_mouse_change_y(n, e.mouse_dy, cfg.id_track, w)
					w.view_state.offset_y_state[cfg.id_track] = offset
				}
			}
		}
	}
}

// pass cfg by value more reliable here
fn (cfg ScrollbarCfg) mouse_up(node &Layout, mut e Event, mut w Window) {
	w.mouse_unlock()
}

// Don't know what the sizes and positions of the scrollbar elements should
// be until after the layout is almost done requiring manual layout here.
// Scrollbars are hard.
fn (cfg &ScrollbarCfg) amend_layout(mut node Layout, mut w Window) {
	thumb := 0
	min_thumb_size := 20
	mut transparent := false
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

	match cfg.orientation == .horizontal {
		true {
			node.shape.x += parent.shape.padding.left
			node.shape.width = parent.shape.width - parent.shape.padding.width()

			total_width := content_width(parent)
			t_width := node.shape.width * (node.shape.width / total_width)
			thumb_width := clamp_f32(t_width, min_thumb_size, node.shape.width)

			available_width := node.shape.width - thumb_width
			scroll_offset := -w.view_state.offset_x_state[cfg.id_track]
			offset := if available_width == 0 {
				0
			} else {
				clamp_f32((scroll_offset / (total_width - node.shape.width)) * available_width,
					0, available_width)
			}
			node.children[thumb].shape.x = node.shape.x + offset
			node.children[thumb].shape.width = thumb_width
			node.children[thumb].shape.height = cfg.size

			if (cfg.overflow != .visible && node.shape.width - thumb_width < 0.1)
				|| cfg.overflow == .on_hover {
				node.children[thumb].shape.color = color_transparent
				transparent = true
			}
		}
		else {
			node.shape.y += parent.shape.padding.top
			node.shape.height = parent.shape.height - parent.shape.padding.height()

			total_height := content_height(parent)
			t_height := node.shape.height * (node.shape.height / total_height)
			thumb_height := clamp_f32(t_height, min_thumb_size, node.shape.height)

			available_height := node.shape.height - thumb_height
			scroll_offset := -w.view_state.offset_y_state[cfg.id_track]
			offset := if available_height == 0 {
				0
			} else {
				clamp_f32((scroll_offset / (total_height - node.shape.height)) * available_height,
					0, available_height)
			}
			node.children[thumb].shape.y = node.shape.y + offset
			node.children[thumb].shape.height = thumb_height
			node.children[thumb].shape.width = cfg.size

			if (cfg.overflow != .visible && node.shape.height - thumb_height < 0.1)
				|| cfg.overflow == .on_hover {
				node.children[thumb].shape.color = color_transparent
				transparent = true
			}
		}
	}
	// on hover dim color of thumb
	ctx := w.context()
	if node.shape.point_in_shape(f32(ctx.mouse_pos_x), f32(ctx.mouse_pos_y)) || w.mouse_is_locked() {
		if w.dialog_cfg.visible && !node_in_dialog_layout(node) {
			return
		}
		if !transparent || cfg.overflow == .on_hover {
			node.children[thumb].shape.color = gui_theme.button_style.color_hover
		}
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

fn offset_mouse_change_x(node Layout, mouse_x f32, id_scroll u32, w &Window) f32 {
	total_width := content_width(node)
	shape_width := node.shape.width - node.shape.padding.width()
	old_offset := w.view_state.offset_x_state[id_scroll]
	new_offset := mouse_x * (total_width / shape_width)
	offset := old_offset - new_offset
	return f32_min(0, f32_max(offset, shape_width - total_width))
}

fn offset_mouse_change_y(node Layout, mouse_y f32, id_scroll u32, w &Window) f32 {
	total_height := content_height(node)
	shape_height := node.shape.height - node.shape.padding.height()
	old_offset := w.view_state.offset_y_state[id_scroll]
	new_offset := mouse_y * (total_height / shape_height)
	offset := old_offset - new_offset
	return f32_min(0, f32_max(offset, shape_height - total_height))
}

fn offset_from_mouse_x(node Layout, mouse_x f32, id_scroll u32, mut w Window) {
	if sb := find_node_by_id_scroll(node, id_scroll) {
		total_width := content_width(sb)
		mut percent := mouse_x / sb.shape.width
		percent = clamp_f32(percent, 0, 1)
		if percent <= 0.03 {
			percent = 0
		}
		if percent >= 0.97 {
			percent = 1
		}
		w.view_state.offset_x_state[id_scroll] = -percent * (total_width - sb.shape.width)
	}
}

fn offset_from_mouse_y(node Layout, mouse_y f32, id_scroll u32, mut w Window) {
	if sb := find_node_by_id_scroll(node, id_scroll) {
		total_height := content_height(sb)
		mut percent := mouse_y / sb.shape.height
		percent = clamp_f32(percent, 0, 1)
		if percent <= 0.03 {
			percent = 0
		}
		if percent >= 0.97 {
			percent = 1
		}
		w.view_state.offset_y_state[id_scroll] = -percent * (total_height - sb.shape.height)
	}
}
