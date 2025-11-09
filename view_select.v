module gui

import hash.fnv1a

// SelectCfg configures a [select](#select) (a.k.a drop-down) view.
@[heap]
pub struct SelectCfg {
pub:
	id                 string @[required] // unique only to other select views
	placeholder        string
	select             []string // Text of select item
	options            []string
	color              Color     = gui_theme.select_style.color
	color_border       Color     = gui_theme.select_style.color_border
	color_border_focus Color     = gui_theme.select_style.color_border_focus
	color_focus        Color     = gui_theme.select_style.color_focus
	color_select       Color     = gui_theme.select_style.color_select
	padding            Padding   = gui_theme.select_style.padding
	padding_border     Padding   = gui_theme.select_style.padding_border
	text_style         TextStyle = gui_theme.select_style.text_style
	subheading_style   TextStyle = gui_theme.select_style.subheading_style
	placeholder_style  TextStyle = gui_theme.select_style.placeholder_style
	on_select          fn ([]string, mut Event, mut Window) @[required]
	min_width          f32 = gui_theme.select_style.min_width
	max_width          f32 = gui_theme.select_style.max_width
	radius             f32 = gui_theme.select_style.radius
	radius_border      f32 = gui_theme.select_style.radius_border
	id_focus           u32
	select_multiple    bool
	no_wrap            bool
	fill               bool = gui_theme.select_style.fill
	fill_border        bool = gui_theme.select_style.fill_border
}

// select creates a select (a.k.a. drop-down) view from the given [SelectCfg](#SelectCfg)
pub fn (window &Window) select(cfg SelectCfg) View {
	is_open := window.view_state.select_state[cfg.id]
	mut options := []View{}
	if is_open {
		options.ensure_cap(cfg.options.len)
		for option in cfg.options {
			options << match option.starts_with('---') {
				true { sub_header(cfg, option) }
				else { option_view(cfg, option) }
			}
		}
	}
	empty := cfg.select.len == 0 || cfg.select[0].len == 0
	clip := if cfg.select_multiple && cfg.no_wrap { true } else { false }
	txt := if empty { cfg.placeholder } else { cfg.select.join(', ') }
	txt_style := if empty { cfg.placeholder_style } else { cfg.text_style }
	wrap_mode := if cfg.select_multiple && !cfg.no_wrap {
		TextMode.wrap
	} else {
		TextMode.single_line
	}

	id := cfg.id
	mut content := []View{cap: 2}
	unsafe { content.flags.set(.noslices) }
	content << row( // interior
		name:     'select interior'
		fill:     cfg.fill
		color:    cfg.color
		padding:  cfg.padding
		sizing:   fill_fit
		content:  [
			text(
				text:       txt
				text_style: txt_style
				mode:       wrap_mode
			),
			row(name: 'select spacer', sizing: fill_fill, padding: padding_none),
			text(
				text:       if is_open { '▲' } else { '▼' }
				text_style: cfg.text_style
			),
		]
		on_click: fn [id, is_open] (_ &Layout, mut e Event, mut w Window) {
			w.view_state.select_state.clear() // close all select drop-downs.
			w.view_state.select_state[id] = !is_open
			e.is_handled = true
		}
	)
	if is_open {
		content << column( // dropdown border
			name:           'select dropdown border'
			id:             cfg.id + 'dropdown'
			min_height:     50
			max_height:     200
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
				column(
					name:    'select dropdown scroll container'
					padding: padding_none
					sizing:  fill_fill
					content: [
						column( // drop down list
							name:      'select dropdown list'
							id:        cfg.id + 'dropdown_list'
							id_scroll: fnv1a.sum32_string(cfg.id + 'dropdown')
							fill:      cfg.fill
							sizing:    fill_fill
							color:     cfg.color
							padding:   padding(pad_small, pad_medium, pad_small, pad_small)
							spacing:   0
							content:   options
						),
					]
				),
			]
		)
	}
	return row( // border
		name:         'select border'
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
	select_multiple := cfg.select_multiple
	on_select := cfg.on_select
	select_array := cfg.select
	color_select := cfg.color_select

	return row(
		fill:     true
		padding:  padding(0, pad_small, 0, 1)
		sizing:   fill_fit
		spacing:  0
		content:  [
			row(
				name:    'select option'
				spacing: 0
				padding: pad_tblr(2, 0)
				content: [
					text(
						text:       '✓'
						text_style: TextStyle{
							...cfg.text_style
							color: if option in cfg.select {
								gui_theme.text_style.color
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
			),
		]
		on_click: fn [on_select, select_multiple, select_array, option] (_ &Layout, mut e Event, mut w Window) {
			if on_select != unsafe { nil } {
				if !select_multiple {
					w.view_state.select_state.clear()
				}

				mut s := []string{}
				if select_multiple {
					s = if option in select_array {
						select_array.filter(it != option)
					} else {
						mut a := select_array.clone()
						a << option
						a.sorted()
					}
				} else {
					w.view_state.select_state.clear()
					s = [option]
				}
				on_select(s, mut e, mut w)
				e.is_handled = true
			}
		}
		on_hover: fn [color_select] (mut layout Layout, mut e Event, mut w Window) {
			w.set_mouse_cursor_pointing_hand()
			layout.shape.color = color_select
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
				name:    'select sub_header'
				padding: padding_none
				sizing:  fill_fit
				spacing: pad_x_small
				content: [
					text(
						text:       '✓'
						text_style: TextStyle{
							...cfg.subheading_style
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
				name:    'select sub_header underline'
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

fn (cfg &SelectCfg) amend_layout(mut layout Layout, mut w Window) {
	if layout.shape.disabled {
		return
	}
	if w.is_focus(layout.shape.id_focus) {
		layout.children[0].shape.color = cfg.color_focus
		layout.shape.color = cfg.color_border_focus
	}
}
