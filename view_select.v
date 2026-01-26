module gui

import hash.fnv1a

// SelectCfg configures a [select](#select) (a.k.a drop-down) view.
@[heap; minify]
pub struct SelectCfg {
pub:
	id                 string @[required] // unique only to other select views
	placeholder        string
	select             []string // Text of select item
	options            []string
	color              Color   = gui_theme.select_style.color
	color_border       Color   = gui_theme.select_style.color_border
	color_border_focus Color   = gui_theme.select_style.color_border_focus
	color_focus        Color   = gui_theme.select_style.color_focus
	color_select       Color   = gui_theme.select_style.color_select
	padding            Padding = gui_theme.select_style.padding
	size_border        f32     = gui_theme.select_style.size_border

	text_style        TextStyle = gui_theme.select_style.text_style
	subheading_style  TextStyle = gui_theme.select_style.subheading_style
	placeholder_style TextStyle = gui_theme.select_style.placeholder_style
	on_select         fn ([]string, mut Event, mut Window) @[required]
	min_width         f32 = gui_theme.select_style.min_width
	max_width         f32 = gui_theme.select_style.max_width
	radius            f32 = gui_theme.select_style.radius
	radius_border     f32 = gui_theme.select_style.radius_border
	id_focus          u32
	select_multiple   bool
	no_wrap           bool
	sizing            Sizing
}

// select creates a select (a.k.a. drop-down) view from the given [SelectCfg](#SelectCfg)
pub fn (window &Window) select(cfg SelectCfg) View {
	is_open := window.view_state.select_state[cfg.id]
	mut options := []View{}
	if is_open {
		id_scroll := fnv1a.sum32_string(cfg.id + 'dropdown')
		highlighted_idx := window.view_state.select_highlight[cfg.id]
		options.ensure_cap(cfg.options.len)
		for i, option in cfg.options {
			options << match option.starts_with('---') {
				true { sub_header(cfg, option) }
				else { option_view(cfg, option, i, i == highlighted_idx, id_scroll) }
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

	mut content := []View{cap: 4}

	content << text(
		text:       txt
		text_style: txt_style
		mode:       wrap_mode
	)
	content << row(
		name:    'select spacer'
		sizing:  if wrap_mode == .single_line { fill_fill } else { fit_fill }
		padding: padding_none
	)
	content << text(
		text:       if is_open { '▲' } else { '▼' }
		text_style: cfg.text_style
	)

	if is_open {
		content << column( // dropdown
			name: 'select dropdown'
			id:   cfg.id + 'dropdown'
			// Border props
			size_border:  cfg.size_border
			radius:       cfg.radius
			color_border: cfg.color_border
			// Background props
			color: cfg.color

			// Layout props
			min_height: 50
			max_height: 200
			min_width:  cfg.min_width
			max_width:  cfg.max_width

			// Float props
			float:          true
			float_anchor:   .bottom_left
			float_tie_off:  .top_left
			float_offset_y: -cfg.size_border

			// List/Scroll Props merged
			id_scroll: fnv1a.sum32_string(cfg.id + 'dropdown')
			padding:   padding(pad_small, pad_medium, pad_small, pad_small)
			spacing:   0
			content:   options
		)
	}

	return row(
		name:     'select'
		id:       cfg.id
		id_focus: cfg.id_focus
		clip:     clip

		// Container props
		color:        cfg.color
		color_border: cfg.color_border
		size_border:  cfg.size_border
		radius:       cfg.radius
		padding:      cfg.padding
		sizing:       cfg.sizing
		min_width:    cfg.min_width
		max_width:    cfg.max_width

		// Behavior
		amend_layout: cfg.amend_layout
		on_keydown:   cfg.select_on_keydown

		// Event Handling (moved from inner)
		on_click: fn [id, is_open] (_ &Layout, mut e Event, mut w Window) {
			w.view_state.select_state.clear() // close all select drop-downs.
			w.view_state.select_state[id] = !is_open
			e.is_handled = true
		}

		content: content
	)
}

fn (cfg &SelectCfg) select_on_keydown(mut _ Layout, mut e Event, mut w Window) {
	if cfg.options.len == 0 {
		return
	}

	is_open := w.view_state.select_state[cfg.id]

	// Open/Close
	if e.key_code in [.space, .enter] && !is_open {
		w.view_state.select_state[cfg.id] = true

		// Set highlight to currently selected item
		mut initial_idx := 0
		if cfg.select.len > 0 {
			for i, opt in cfg.options {
				if opt == cfg.select[0] {
					initial_idx = i
					break
				}
			}
		}
		w.view_state.select_highlight[cfg.id] = initial_idx

		e.is_handled = true
		return
	}

	if e.key_code == .escape && is_open {
		w.view_state.select_state.clear()
		e.is_handled = true
		return
	}

	if is_open {
		mut current_idx := w.view_state.select_highlight[cfg.id]
		id_scroll := fnv1a.sum32_string(cfg.id + 'dropdown')

		if e.key_code == .enter {
			// Select currently highlighted
			if current_idx >= 0 && current_idx < cfg.options.len {
				option := cfg.options[current_idx]
				if !option.starts_with('---') {
					// Trigger selection logic (duplicated from option_view click)
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
			return
		}

		if e.key_code in [.up, .down] {
			dir := if e.key_code == .up { -1 } else { 1 }
			mut next_idx := current_idx + dir

			// Skip subheaders and bounds check
			for next_idx >= 0 && next_idx < cfg.options.len {
				if !cfg.options[next_idx].starts_with('---') {
					break
				}
				next_idx += dir
			}

			// Clamp
			if next_idx < 0 {
				// Find first non-header
				next_idx = 0
				for next_idx < cfg.options.len && cfg.options[next_idx].starts_with('---') {
					next_idx++
				}
			} else if next_idx >= cfg.options.len {
				// Find last non-header
				next_idx = cfg.options.len - 1
				for next_idx >= 0 && cfg.options[next_idx].starts_with('---') {
					next_idx--
				}
			}

			if next_idx >= 0 && next_idx < cfg.options.len
				&& !cfg.options[next_idx].starts_with('---') {
				w.view_state.select_highlight[cfg.id] = next_idx
				// Scroll to view
				// Estimate row height: text size + padding (4)
				row_h := cfg.text_style.size + 4
				// Simple scroll to top of item
				// Better: ensure visible. But view_state.scroll_y is just offset.
				// We can set it to center the item or just show it.
				// Let's just set it to `next_idx * row_h` to keep it simple for now,
				// which puts the item at top.
				// To be smarter we'd need current viewport height.
				w.view_state.scroll_y[id_scroll] = next_idx * row_h
			}
			e.is_handled = true
		}
	}
}

fn option_view(cfg &SelectCfg, option string, index int, highlighted bool, id_scroll u32) View {
	select_multiple := cfg.select_multiple
	on_select := cfg.on_select
	select_array := cfg.select
	color_select := cfg.color_select

	return row(
		color:    if highlighted { cfg.color_select } else { color_transparent }
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
		on_hover: fn [color_select, cfg, index, id_scroll] (mut layout Layout, mut e Event, mut w Window) {
			w.set_mouse_cursor_pointing_hand()
			layout.shape.color = color_select
			if w.view_state.select_highlight[cfg.id] != index {
				w.view_state.select_highlight[cfg.id] = index
				// w.view_state.scroll_y[id_scroll] = ... // Don't auto-scroll on mouse hover, that's annoying
			}
		}
	)
}

fn sub_header(cfg &SelectCfg, option string) View {
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
		layout.shape.color = cfg.color_focus
		layout.shape.color_border = cfg.color_border_focus
	}
}
