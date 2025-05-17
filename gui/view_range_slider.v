module gui

import rand

@[heap]
pub struct RangeSliderCfg {
pub:
	id              string
	id_focus        u32
	percent         f32 // 0.0 <= percent <= 1.0
	vertical        bool
	disabled        bool
	invisible       bool
	sizing          Sizing
	size            f32                             = gui_theme.range_slider_style.size
	thumb_size      f32                             = gui_theme.range_slider_style.thumb_size
	fill            bool                            = gui_theme.range_slider_style.fill
	fill_border     bool                            = gui_theme.range_slider_style.fill_border
	color           Color                           = gui_theme.range_slider_style.color
	color_border    Color                           = gui_theme.range_slider_style.color_border
	color_thumb     Color                           = gui_theme.range_slider_style.color_thumb
	color_focus     Color                           = gui_theme.range_slider_style.color_focus
	color_hover     Color                           = gui_theme.range_slider_style.color_hover
	color_left      Color                           = gui_theme.range_slider_style.color_left
	color_click     Color                           = gui_theme.range_slider_style.color_click
	padding         Padding                         = gui_theme.range_slider_style.padding
	padding_border  Padding                         = gui_theme.range_slider_style.padding_border
	radius          f32                             = gui_theme.range_slider_style.radius
	radius_border   f32                             = gui_theme.range_slider_style.radius_border
	percent_changed fn (f32, mut Event, mut Window) = unsafe { nil }
}

pub fn range_slider(cfg RangeSliderCfg) View {
	return row(
		id:           cfg.id
		width:        cfg.size
		height:       cfg.size
		disabled:     cfg.disabled
		invisible:    cfg.invisible
		color:        cfg.color_border
		radius:       cfg.radius_border
		padding:      cfg.padding_border
		fill:         cfg.fill_border
		sizing:       cfg.sizing
		h_align:      .center
		v_align:      .middle
		amend_layout: cfg.amend_layout_slide
		content:      [
			row(
				color:   cfg.color
				fill:    true
				radius:  cfg.radius
				sizing:  fill_fill
				padding: padding_none
				content: [
					circle(
						id:            rand.u64().str() // helps mouse_move find it
						float:         true
						float_anchor:  .middle_left
						float_tie_off: .middle_center
						width:         cfg.thumb_size
						height:        cfg.thumb_size
						fill:          cfg.fill
						color:         cfg.color_thumb
						on_click:      cfg.on_mouse_down
						amend_layout:  cfg.amend_layout_thumb
					),
				]
			),
		]
	)
}

fn (cfg &RangeSliderCfg) on_mouse_down(_ voidptr, mut e Event, mut w Window) {
	w.mouse_lock(MouseLockCfg{
		mouse_move: cfg.mouse_move
		mouse_up:   fn (node &Layout, mut e Event, mut w Window) {
			w.mouse_unlock()
		}
	})
}

// pass cfg by value more reliable here
fn (cfg RangeSliderCfg) mouse_move(node &Layout, mut e Event, mut w Window) {
	if cfg.percent_changed != unsafe { nil } {
		if node_circle := node.find_node(fn [cfg] (n Layout) bool {
			return n.shape.id == cfg.id
		})
		{
			shape := node_circle.parent.shape
			width := shape.width
			percent := clamp_f32((e.mouse_x - shape.x) / width, 0, 1)
			cfg.percent_changed(percent, mut e, mut w)
		}
	}
}

fn (cfg &RangeSliderCfg) on_mouse_down_shape(shape &Shape, mut e Event, mut w Window) {
	if cfg.percent_changed != unsafe { nil } {
		width := shape.width
		percent := clamp_f32((e.mouse_x - shape.x) / width, 0, 1)
		cfg.percent_changed(percent, mut e, mut w)
	}
}

fn (cfg &RangeSliderCfg) amend_layout_slide(mut node Layout, mut w Window) {
	node.shape.on_mouse_down_shape = cfg.on_mouse_down_shape
}

fn (cfg &RangeSliderCfg) amend_layout_thumb(mut node Layout, mut w Window) {
	slider_reveal := 2
	percent := clamp_f32(cfg.percent, 0, 1)
	if cfg.vertical {
		height := node.parent.shape.height - node.shape.height - slider_reveal - slider_reveal
		y := f32_min(height * percent, height)
		node.shape.y += y + slider_reveal + node.shape.height / 2
	} else {
		width := node.parent.shape.width - node.shape.width - slider_reveal - slider_reveal
		x := f32_min(width * percent, width)
		node.shape.x += x + slider_reveal + node.shape.width / 2
	}
}
