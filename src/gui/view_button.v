module gui

import gg
import gx

// ButtonCfgconfigures a clickable button. It won't respond mouse
// interactions if an on_click handler is not provided. In that mode,
// it functions as bubble text.
//
pub struct ButtonCfg {
pub:
	id               string
	id_focus         u32
	width            f32
	height           f32
	min_width        f32
	min_height       f32
	max_width        f32
	max_height       f32
	h_align          HorizontalAlign
	v_align          VerticalAlign
	sizing           Sizing
	text             string
	content          []View
	fill             bool       = gui_theme.fill_button
	fill_border      bool       = gui_theme.fill_button_border
	color            gx.Color   = gui_theme.color_button
	color_focus      gx.Color   = gui_theme.color_button_focus
	color_hover      gx.Color   = gui_theme.color_button_hover
	color_click      gx.Color   = gui_theme.color_button_click
	color_click_text gx.Color   = gui_theme.color_button_click_text
	color_border     gx.Color   = gui_theme.color_button_border
	padding_border   Padding    = gui_theme.padding_button_border
	padding          Padding    = gui_theme.padding_button
	radius           f32        = gui_theme.radius_button
	text_style       gx.TextCfg = gui_theme.text_cfg
	on_click         fn (&ButtonCfg, &gg.Event, &Window) bool = unsafe { nil }
}

// button creates a button. Imagine that.
pub fn button(cfg ButtonCfg) View {
	mut content := []View{}
	if cfg.content.len > 0 {
		content = cfg.content.clone()
	} else {
		content = [text(
			text:  cfg.text
			style: cfg.text_style
		)]
	}

	return row(
		color:    cfg.color_border
		padding:  cfg.padding_border
		fill:     cfg.fill_border
		children: [
			row(
				id:           cfg.id
				id_focus:     cfg.id_focus
				width:        cfg.width
				height:       cfg.height
				min_width:    cfg.min_width
				min_height:   cfg.min_height
				max_width:    cfg.max_width
				max_height:   cfg.max_height
				padding:      cfg.padding
				sizing:       cfg.sizing
				radius:       cfg.radius
				fill:         cfg.fill
				v_align:      cfg.v_align
				h_align:      cfg.h_align
				color:        cfg.color
				cfg:          &ButtonCfg{ // allocate on heap
					...cfg
				}
				on_click:     cfg.on_click
				on_char:      on_char_button
				amend_layout: cfg.amend_layout
				children:     content
			),
		]
	)
}

fn on_char_button(cfg &ButtonCfg, e &gg.Event, mut w Window) bool {
	if e.char_code == ` ` && cfg.on_click != unsafe { nil } {
		cfg.on_click(&cfg, e, w)
		return true
	}
	return false
}

fn (cfg ButtonCfg) amend_layout(mut node ShapeTree, mut w Window) {
	if cfg.on_click == unsafe { nil } {
		return
	}
	if node.shape.id_focus > 0 && node.shape.id_focus == w.id_focus() {
		node.shape.color = cfg.color_focus
	}
	ctx := w.context()
	if node.shape.point_in_shape(f32(ctx.mouse_pos_x), f32(ctx.mouse_pos_y)) {
		w.set_mouse_cursor_pointing_hand()
		node.shape.color = cfg.color_hover
		if ctx.mouse_buttons == gg.MouseButtons.left {
			node.shape.color = cfg.color_click
			node.children[0].shape.text_cfg = gx.TextCfg{
				...node.children[0].shape.text_cfg
				color: cfg.color_click_text
			}
		}
	}
}
