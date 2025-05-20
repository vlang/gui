module gui

import gg
import hash.fnv1a

@[heap]
pub struct SelectCfg {
pub:
	id          string  @[required]
	window      &Window @[required]
	selected    string
	size        u32
	color_hover Color     = gui_theme.color_4
	color_click Color     = gui_theme.color_5
	text_style  TextStyle = gui_theme.n3
	on_select   fn (string, mut Event, mut Window) = unsafe { nil }
	options     []string
}

pub fn select(cfg SelectCfg) View {
	is_open := cfg.window.view_state.select_state[cfg.id]
	mut options := []View{}
	if is_open {
		for option in cfg.options {
			options << option_view(cfg, option)
		}
	}

	mut content := []View{}
	content << row( // interior
		fill:     gui_theme.button_style.fill
		color:    gui_theme.button_style.color
		padding:  gui_theme.padding_small
		sizing:   fill_fit
		on_click: fn [cfg, is_open] (_ &ToggleCfg, mut e Event, mut w Window) {
			w.view_state.select_state[cfg.id] = !is_open
			e.is_handled = true
		}
		content:  [
			text(text: cfg.selected, text_style: cfg.text_style),
			row(sizing: fill_fill, padding: padding_none),
			text(
				text:       if is_open { '▲' } else { '▼' }
				text_style: cfg.text_style
			),
		]
	)
	if is_open {
		_, h := cfg.window.window_size()

		content << column( // dropdown border
			id_scroll:      fnv1a.sum32_string(cfg.id + 'dropdown')
			min_height:     50
			max_height:     clamp_f32(h, 50, h / 2)
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
		)
	}
	return row(
		min_width: 200
		fill:      true
		padding:   gui_theme.padding_border
		radius:    gui_theme.radius_small
		color:     gui_theme.button_style.color_border
		sizing:    fill_fit
		content:   content
	)
}

fn option_view(cfg SelectCfg, option string) View {
	return row(
		fill:         true
		padding:      padding(pad_small, pad_small, pad_small, 1)
		sizing:       fill_fit
		spacing:      pad_x_small
		content:      [
			text(
				text:       '✓'
				text_style: TextStyle{
					...cfg.text_style
					color: if cfg.selected == option {
						cfg.text_style.color
					} else {
						color_transparent
					}
				}
			),
			text(
				text:       option
				text_style: cfg.text_style
			),
		]
		on_click:     fn [cfg, option] (_ voidptr, mut e Event, mut w Window) {
			if cfg.on_select != unsafe { nil } {
				w.view_state.select_state[cfg.id] = false
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
