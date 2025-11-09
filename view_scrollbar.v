module gui

// ScrollbarOverflow determines how scrollbars are shown.
// Remember that to set id_scroll > 0 or these options
// have no effect.
//
// - auto shows scrollbar when required
// - hidden hides the scrollbar
// - visible always shows the scroll bar
// - on_hover show only when mouse is over scrollbar
pub enum ScrollbarOverflow as u8 {
	auto
	hidden
	visible
	on_hover
}

// ScrollbarOrientation determines the scrollbar's orientation.
// Default is vertical.
pub enum ScrollbarOrientation as u8 {
	vertical
	horizontal
}

// ScrollMode allows scrolling in one or both directions. Default is both
pub enum ScrollMode as u8 {
	both
	vertical_only
	horizontal_only
}

// ScrollbarCfg configures the style of a scrollbar. Column and Row
// define a default ScrollbarCfgs so most of the time it is only
// needed to define id_scroll in the Column/Row config. Scrollbars are
// optional. Columns/Rows are scrollable without visible scrollbars.
// [ScrollbarOverflow](#ScrollbarOverflow)
@[heap]
pub struct ScrollbarCfg {
pub:
	id               string
	color_thumb      Color = gui_theme.scrollbar_style.color_thumb
	color_background Color = gui_theme.scrollbar_style.color_background
	size             f32   = gui_theme.scrollbar_style.size
	radius           f32   = gui_theme.scrollbar_style.radius
	radius_thumb     f32   = gui_theme.scrollbar_style.radius_thumb
	offset_x         f32   = gui_theme.scrollbar_style.offset_x // x and y are swapped in
	offset_y         f32   = gui_theme.scrollbar_style.offset_y // horizontal orientation
	id_track         u32
	overflow         ScrollbarOverflow
	orientation      ScrollbarOrientation
	fill_thumb       bool = gui_theme.scrollbar_style.fill_thumb
	fill_background  bool = gui_theme.scrollbar_style.fill_background
}

const scrollbar_vertical_name = 'scrollbar vertical'
const scrollbar_horizontal_name = 'scrollbar horizontal'

// scrollbar creates a scrollbar.
pub fn scrollbar(cfg ScrollbarCfg) View {
	return if cfg.orientation == .horizontal {
		row(
			name:         scrollbar_horizontal_name
			id:           cfg.id
			fill:         cfg.fill_background
			color:        cfg.color_background
			over_draw:    true
			spacing:      0
			padding:      padding_none
			amend_layout: cfg.amend_layout
			on_hover:     cfg.on_hover
			on_click:     cfg.gutter_click
			content:      [
				thumb(cfg, '__thumb__${cfg.id_track}'),
			]
		)
	} else {
		column(
			name:         scrollbar_vertical_name
			id:           cfg.id
			fill:         cfg.fill_background
			color:        cfg.color_background
			over_draw:    true
			spacing:      0
			padding:      padding_none
			amend_layout: cfg.amend_layout
			on_hover:     cfg.on_hover
			on_click:     cfg.gutter_click
			content:      [
				thumb(cfg, '__thumb__${cfg.id_track}'),
			]
		)
	}
}

fn thumb(cfg &ScrollbarCfg, id string) View {
	return column(
		name:     'scrollbar thumb'
		id:       id
		color:    cfg.color_thumb
		fill:     cfg.fill_thumb
		radius:   cfg.radius_thumb
		padding:  padding_none
		spacing:  0
		on_click: cfg.on_mouse_down
	)
}

// on_mouse_down pass cfg by value more reliable here
fn (cfg ScrollbarCfg) on_mouse_down(_ voidptr, mut e Event, mut w Window) {
	// Clicking on the scrollbar gives focus to the shape it is tracking
	// if the tracked shape is not disabled.
	id_track := cfg.id_track
	if shape := w.layout.find_shape(fn [id_track] (n Layout) bool {
		return n.shape.id_scroll == id_track
	})
	{
		if !shape.disabled {
			w.set_id_focus(shape.id_focus)
		}
	}
	w.mouse_lock(MouseLockCfg{
		mouse_move: cfg.mouse_move
		mouse_up:   cfg.mouse_up
	})
	e.is_handled = true
}

// gutter_click pass cfg by value more reliable here
fn (cfg ScrollbarCfg) gutter_click(_ &Layout, mut e Event, mut w Window) {
	if !w.mouse_is_locked() {
		match cfg.orientation == .horizontal {
			true { offset_from_mouse_x(w.layout, e.mouse_x, cfg.id_track, mut w) }
			else { offset_from_mouse_y(w.layout, e.mouse_y, cfg.id_track, mut w) }
		}
		e.is_handled = true
	}
}

// mouse_move pass cfg by value more reliable here
fn (cfg ScrollbarCfg) mouse_move(layout &Layout, mut e Event, mut w Window) {
	extend := 10 // give some cushion on the ends of the scroll range
	if n := find_layout_by_id_scroll(layout, cfg.id_track) {
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

// mouse_up pass cfg by value more reliable here
fn (cfg ScrollbarCfg) mouse_up(_ &Layout, mut e Event, mut w Window) {
	w.mouse_unlock()
}

// amend_layout Don't know what the sizes and positions of the scrollbar elements should
// be until after the layout is almost done requiring manual layout here.
// Scrollbars are hard.
fn (cfg &ScrollbarCfg) amend_layout(mut layout Layout, mut w Window) {
	thumb := 0
	min_thumb_size := 20
	mut parent := layout.parent

	match cfg.orientation == .horizontal {
		true {
			layout.shape.x = parent.shape.x + parent.shape.padding.left
			layout.shape.y = parent.shape.y + parent.shape.height - cfg.size + cfg.offset_y
			layout.shape.width = parent.shape.width - parent.shape.padding.width()
			layout.shape.height = cfg.size

			total_width := content_width(parent)
			t_width := layout.shape.width * (layout.shape.width / total_width)
			thumb_width := f32_clamp(t_width, min_thumb_size, layout.shape.width)

			available_width := layout.shape.width - thumb_width
			scroll_offset := -w.view_state.offset_x_state[cfg.id_track]
			offset := if available_width == 0 {
				0
			} else {
				f32_clamp((scroll_offset / (total_width - layout.shape.width)) * available_width,
					0, available_width)
			}
			layout.children[thumb].shape.x = layout.shape.x + offset
			layout.children[thumb].shape.y = layout.shape.y
			layout.children[thumb].shape.width = thumb_width
			layout.children[thumb].shape.height = cfg.size

			if (cfg.overflow != .visible && layout.shape.width - thumb_width < 0.1)
				|| cfg.overflow == .on_hover {
				layout.children[thumb].shape.color = color_transparent
			}
		}
		else {
			layout.shape.x = parent.shape.x + parent.shape.width - cfg.size + cfg.offset_x
			layout.shape.y = parent.shape.y + parent.shape.padding.top
			layout.shape.width = cfg.size
			layout.shape.height = parent.shape.height - parent.shape.padding.height()

			total_height := content_height(parent)
			t_height := layout.shape.height * (layout.shape.height / total_height)
			thumb_height := f32_clamp(t_height, min_thumb_size, layout.shape.height)

			available_height := layout.shape.height - thumb_height
			scroll_offset := -w.view_state.offset_y_state[cfg.id_track]
			offset := if available_height == 0 {
				0
			} else {
				f32_clamp((scroll_offset / (total_height - layout.shape.height)) * available_height,
					0, available_height)
			}
			layout.children[thumb].shape.x = layout.shape.x
			layout.children[thumb].shape.y = layout.shape.y + offset
			layout.children[thumb].shape.height = thumb_height
			layout.children[thumb].shape.width = cfg.size

			if (cfg.overflow != .visible && layout.shape.height - thumb_height < 0.1)
				|| cfg.overflow == .on_hover {
				layout.children[thumb].shape.color = color_transparent
			}
		}
	}
}

fn (cfg &ScrollbarCfg) on_hover(mut layout Layout, mut _ Event, mut w Window) {
	// on hover dim color of thumb
	thumb := 0
	if layout.children[thumb].shape.color != color_transparent || cfg.overflow == .on_hover {
		layout.children[thumb].shape.color = gui_theme.button_style.color_hover
	}
}

fn find_layout_by_id_scroll(layout &Layout, id_scroll u32) ?Layout {
	if layout.shape.id_scroll == id_scroll {
		return *layout
	}
	for child in layout.children {
		if ly := find_layout_by_id_scroll(child, id_scroll) {
			return ly
		}
	}
	return none
}

fn offset_mouse_change_x(layout &Layout, mouse_x f32, id_scroll u32, w &Window) f32 {
	total_width := content_width(layout)
	shape_width := layout.shape.width - layout.shape.padding.width()
	old_offset := w.view_state.offset_x_state[id_scroll]
	new_offset := mouse_x * (total_width / shape_width)
	offset := old_offset - new_offset
	return f32_min(0, f32_max(offset, shape_width - total_width))
}

fn offset_mouse_change_y(layout &Layout, mouse_y f32, id_scroll u32, w &Window) f32 {
	total_height := content_height(layout)
	shape_height := layout.shape.height - layout.shape.padding.height()
	old_offset := w.view_state.offset_y_state[id_scroll]
	new_offset := mouse_y * (total_height / shape_height)
	offset := old_offset - new_offset
	return f32_min(0, f32_max(offset, shape_height - total_height))
}

fn offset_from_mouse_x(layout &Layout, mouse_x f32, id_scroll u32, mut w Window) {
	if sb := find_layout_by_id_scroll(layout, id_scroll) {
		total_width := content_width(sb)
		mut percent := mouse_x / sb.shape.width
		percent = f32_clamp(percent, 0, 1)
		if percent <= 0.03 {
			percent = 0
		}
		if percent >= 0.97 {
			percent = 1
		}
		w.view_state.offset_x_state[id_scroll] = -percent * (total_width - sb.shape.width)
	}
}

fn offset_from_mouse_y(layout &Layout, mouse_y f32, id_scroll u32, mut w Window) {
	if sb := find_layout_by_id_scroll(layout, id_scroll) {
		total_height := content_height(sb)
		mut percent := mouse_y / sb.shape.height
		percent = f32_clamp(percent, 0, 1)
		if percent <= 0.03 {
			percent = 0
		}
		if percent >= 0.97 {
			percent = 1
		}
		w.view_state.offset_y_state[id_scroll] = -percent * (total_height - sb.shape.height)
	}
}
