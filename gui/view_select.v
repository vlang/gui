module gui

import gg
import hash.fnv1a

@[heap]
pub struct SelectCfg {
pub:
	id                 string  @[required]
	window             &Window @[required]
	selected           string
	color              Color     = gui_theme.select_style.color
	color_border       Color     = gui_theme.select_style.color_border
	color_border_focus Color     = gui_theme.select_style.color_border_focus
	color_click        Color     = gui_theme.select_style.color_click
	color_focus        Color     = gui_theme.select_style.color_focus
	color_hover        Color     = gui_theme.select_style.color_hover
	color_selected     Color     = gui_theme.select_style.color_selected
	fill               bool      = gui_theme.select_style.fill
	fill_border        bool      = gui_theme.select_style.fill_border
	padding            Padding   = gui_theme.select_style.padding
	padding_border     Padding   = gui_theme.select_style.padding_border
	radius             f32       = gui_theme.select_style.radius
	radius_border      f32       = gui_theme.select_style.radius_border
	subheading_style   TextStyle = gui_theme.select_style.subheading_style
	on_select          fn (string, mut Event, mut Window) = unsafe { nil }
	options            []string
}

pub fn select(cfg SelectCfg) View {
	is_open := cfg.window.view_state.select_state[cfg.id]
	mut options := []View{}
	if is_open {
		for option in cfg.options {
			options << match option.starts_with('---') {
				true { sub_header(cfg, option) }
				else { option_view(cfg, option) }
			}
		}
	}

	mut content := []View{}
	content << row( // interior
		fill:     cfg.fill
		color:    cfg.color
		padding:  cfg.padding
		sizing:   fill_fit
		on_click: fn [cfg, is_open] (_ &ToggleCfg, mut e Event, mut w Window) {
			w.view_state.select_state.clear() // close all select drop-downs.
			w.view_state.select_state[cfg.id] = !is_open
			e.is_handled = true
		}
		content:  [
			text(text: cfg.selected),
			row(sizing: fill_fill, padding: padding_none),
			text(
				text: if is_open { '▲' } else { '▼' }
			),
		]
	)
	if is_open {
		_, h := cfg.window.window_size()

		content << column( // dropdown border
			id:             cfg.id + 'dropdown'
			id_scroll:      fnv1a.sum32_string(cfg.id + 'dropdown')
			min_height:     50
			max_height:     clamp_f32(h, 50, h / 2)
			float:          true
			float_anchor:   .bottom_left
			float_tie_off:  .top_left
			float_offset_y: -cfg.padding_border.top
			fill:           cfg.fill
			padding:        cfg.padding_border
			radius:         cfg.radius
			color:          cfg.color_border
			content:        [
				column( // interior list
					fill:    cfg.fill
					color:   cfg.color
					padding: padding(pad_small, pad_medium, pad_small, pad_small)
					spacing: 0
					content: options
				),
			]
		)
	}
	return row(
		id:        cfg.id
		min_width: 200
		fill:      true
		padding:   cfg.padding_border
		radius:    cfg.radius
		color:     cfg.color_border
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
					...gui_theme.text_style
					color: if cfg.selected == option {
						gui_theme.text_style.color
					} else {
						color_transparent
					}
				}
			),
			text(text: option),
		]
		on_click:     fn [cfg, option] (_ voidptr, mut e Event, mut w Window) {
			if cfg.on_select != unsafe { nil } {
				w.view_state.select_state.clear() // close all select drop-downs.
				cfg.on_select(option, mut e, mut w)
				e.is_handled = true
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
				w.set_mouse_cursor_pointing_hand()
				node.shape.color = cfg.color_hover
				if ctx.mouse_buttons == gg.MouseButtons.left {
					node.shape.color = cfg.color_click
				}
			}
		}
	)
}

fn sub_header(cfg SelectCfg, option string) View {
	return column(
		spacing: 0
		padding: padding(gui_theme.padding_medium.top, 0, 0, 0)
		sizing:  fill_fit
		content: [
			row(
				padding: padding_none
				sizing:  fill_fit
				spacing: pad_x_small
				content: [
					text(
						text:       '✓'
						text_style: TextStyle{
							...gui_theme.text_style
							color: color_transparent
						}
					),
					text(
						text:       option[3..]
						text_style: cfg.subheading_style
					),
				]
			),
			row(
				padding: pad_tblr(0, pad_medium)
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
}
