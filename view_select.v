module gui

import hash.fnv1a

// SelectCfg configures a [select](#select) (a.k.a drop-down) view.
@[heap]
pub struct SelectCfg {
pub:
	id                 string  @[required] // unique only to other select views
	window             &Window @[required] // required for state managment
	id_focus           u32
	select             []string // Text of select item
	placeholder        string
	select_multiple    bool
	no_wrap            bool
	min_width          f32       = gui_theme.select_style.min_width
	max_width          f32       = gui_theme.select_style.max_width
	color              Color     = gui_theme.select_style.color
	color_border       Color     = gui_theme.select_style.color_border
	color_border_focus Color     = gui_theme.select_style.color_border_focus
	color_focus        Color     = gui_theme.select_style.color_focus
	color_select       Color     = gui_theme.select_style.color_select
	fill               bool      = gui_theme.select_style.fill
	fill_border        bool      = gui_theme.select_style.fill_border
	padding            Padding   = gui_theme.select_style.padding
	padding_border     Padding   = gui_theme.select_style.padding_border
	radius             f32       = gui_theme.select_style.radius
	radius_border      f32       = gui_theme.select_style.radius_border
	subheading_style   TextStyle = gui_theme.select_style.subheading_style
	placeholder_style  TextStyle = gui_theme.select_style.placeholder_style
	on_select          fn ([]string, mut Event, mut Window) @[required]
	options            []string
}

// select creates a select (a.k.a. drop-down) view from the given [SelectCfg](#SelectCfg)
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
	clip := if cfg.select_multiple && cfg.no_wrap { true } else { false }
	txt := if cfg.select.len == 0 { cfg.placeholder } else { cfg.select.join(', ') }
	txt_style := if cfg.select.len == 0 { cfg.placeholder_style } else { gui_theme.text_style }
	wrap_mode := if cfg.select_multiple && !cfg.no_wrap {
		TextMode.wrap
	} else {
		TextMode.single_line
	}

	mut content := []View{}
	content << row( // interior
		fill:     cfg.fill
		color:    cfg.color
		padding:  cfg.padding
		sizing:   fill_fit
		content:  [
			text(text: txt, text_style: txt_style, mode: wrap_mode),
			row(sizing: fill_fill, padding: padding_none),
			text(
				text: if is_open { '▲' } else { '▼' }
			),
		]
		on_click: fn [cfg, is_open] (_ &ToggleCfg, mut e Event, mut w Window) {
			w.view_state.select_state.clear() // close all select drop-downs.
			w.view_state.select_state[cfg.id] = !is_open
			e.is_handled = true
		}
	)
	if is_open {
		_, h := cfg.window.window_size()

		content << column( // dropdown border
			id:             cfg.id + 'dropdown'
			id_scroll:      fnv1a.sum32_string(cfg.id + 'dropdown')
			min_height:     50
			max_height:     clamp_f32(h, 50, h / 2)
			min_width:      cfg.min_width
			max_width:      cfg.max_width
			float:          true
			float_anchor:   .bottom_left
			float_tie_off:  .top_left
			float_offset_y: -cfg.padding_border.top
			fill:           cfg.fill
			padding:        cfg.padding_border
			radius:         cfg.radius
			color:          cfg.color_border
			content:        [
				column( // drop down list
					fill:    cfg.fill
					sizing:  fill_fill
					color:   cfg.color
					padding: padding(pad_small, pad_medium, pad_small, pad_small)
					spacing: 0
					content: options
				),
			]
		)
	}
	return row( // border
		id:           cfg.id
		id_focus:     cfg.id_focus
		clip:         clip
		fill:         true
		min_width:    cfg.min_width
		max_width:    cfg.max_width
		padding:      cfg.padding_border
		radius:       cfg.radius
		color:        cfg.color_border
		sizing:       fill_fit
		amend_layout: cfg.amend_layout
		content:      content
	)
}

fn option_view(cfg SelectCfg, option string) View {
	return row(
		fill:     true
		padding:  padding(0, pad_small, 0, 1)
		sizing:   fill_fit
		spacing:  0
		content:  [
			row(
				spacing: 0
				padding: pad_tblr(2, 0)
				content: [
					text(
						text:       '✓'
						text_style: TextStyle{
							...gui_theme.text_style
							color: if option in cfg.select {
								gui_theme.text_style.color
							} else {
								color_transparent
							}
						}
					),
					text(text: option),
				]
			),
		]
		on_click: fn [cfg, option] (_ voidptr, mut e Event, mut w Window) {
			if cfg.on_select != unsafe { nil } {
				if !cfg.select_multiple {
					w.view_state.select_state.clear()
				}

				mut s := []string{}
				if cfg.select_multiple {
					s = if option in cfg.select {
						cfg.select.filter(it != option)
					} else {
						mut a := cfg.select.clone()
						a << option
						a.sorted()
					}
				} else {
					w.view_state.select_state.clear()
					s = [option]
				}
				cfg.on_select(s, mut e, mut w)
				e.is_handled = true
			}
		}
		on_hover: fn [cfg] (mut node Layout, mut e Event, mut w Window) {
			if node.shape.disabled {
				return
			}
			w.set_mouse_cursor_pointing_hand()
			node.shape.color = cfg.color_select
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

fn (cfg &SelectCfg) amend_layout(mut node Layout, mut w Window) {
	if node.shape.disabled {
		return
	}
	if w.is_focus(node.shape.id_focus) {
		node.children[0].shape.color = cfg.color_focus
		node.shape.color = cfg.color_border_focus
	}
}
