module gui

import gg

pub struct SelectCfg {
pub:
	id          string @[required]
	selected    string
	is_open     bool
	size        u32
	color_hover Color     = gui_theme.color_4
	color_click Color     = gui_theme.color_5
	text_style  TextStyle = gui_theme.n3
	on_select   fn (string, mut Event, mut Window) = unsafe { nil }
	options     []string
}

pub fn select(cfg SelectCfg) View {
	mut options := []View{}
	for option in cfg.options {
		options << option_view(cfg, option)
	}
	return row(
		min_width: 200
		fill:      true
		padding:   gui_theme.padding_border
		radius:    gui_theme.radius_small
		color:     gui_theme.button_style.color_border
		sizing:    fill_fit
		content:   [
			row( // interior
				fill:    gui_theme.button_style.fill
				color:   gui_theme.button_style.color
				padding: pad_tblr(pad_x_small, pad_medium)
				sizing:  fill_fit
				content: [
					text(text: cfg.selected, text_style: cfg.text_style),
					row(sizing: fill_fill, padding: padding_none),
					text(
						text:       if cfg.is_open { '▲' } else { '▼' }
						text_style: cfg.text_style
					),
				]
			),
			column( // dropdown border
				float:          true
				float_anchor:   .bottom_left
				float_tie_off:  .top_left
				float_offset_y: -gui_theme.button_style.padding_border.bottom
				fill:           true
				padding:        gui_theme.padding_border
				radius:         gui_theme.radius_small
				color:          gui_theme.button_style.color_border
				content:        [
					column( // interior list
						fill:    gui_theme.button_style.fill
						color:   gui_theme.button_style.color
						padding: padding_x_small
						spacing: 0
						content: options
					),
				]
			),
		]
	)
}

fn option_view(cfg SelectCfg, option string) View {
	return row(
		fill:         true
		padding:      pad_tblr(pad_x_small, pad_small)
		sizing:       fill_fit
		content:      [text(text: option, text_style: cfg.text_style)]
		on_click:     fn [cfg, option] (_ voidptr, mut e Event, mut w Window) {
			if cfg.on_select != unsafe { nil } {
				cfg.on_select(option, mut e, mut w)
			}
		}
		amend_layout: fn [cfg] (mut node Layout, mut w Window) {
			if node.shape.disabled {
				return
			}
			ctx := w.context()
			if node.shape.point_in_shape(f32(ctx.mouse_pos_x), f32(ctx.mouse_pos_y)) {
				if w.dialog_cfg.visible && !node_in_dialog_layout(node) {
					return
				}
				node.shape.color = cfg.color_hover
				if ctx.mouse_buttons == gg.MouseButtons.left {
					node.shape.color = cfg.color_click
				}
			}
		}
	)
}
