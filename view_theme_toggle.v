module gui

import hash.fnv1a

// ThemeToggleCfg configures a [theme_toggle](#theme_toggle) view.
// Displays a palette icon that opens a floating dropdown listing
// all registered themes.
@[minify]
pub struct ThemeToggleCfg {
pub:
	id             string @[required]
	id_focus       u32
	sizing         Sizing
	on_select      fn (string, mut Event, mut Window) = unsafe { nil }
	float_anchor   FloatAttach                        = .bottom_left
	float_tie_off  FloatAttach                        = .top_left
	float_offset_x f32
	float_offset_y f32
}

// theme_toggle creates a toggle icon that opens a dropdown of
// registered themes for selection.
pub fn (window &Window) theme_toggle(cfg ThemeToggleCfg) View {
	is_open := state_read_or[string, bool](window, ns_select, cfg.id, false)
	id := cfg.id
	current_name := gui_theme.name
	id_focus := cfg.id_focus
	on_sel := cfg.on_select
	lb_id := cfg.id + 'lb'

	mut content := []View{cap: 2}

	content << text(
		text:       icon_palette
		text_style: gui_theme.icon3
	)

	if is_open {
		mut names := gui_theme_registry.keys()
		names.sort()
		mut data := []ListBoxOption{cap: names.len}
		for name in names {
			data << list_box_option(name, name, name)
		}
		content << column(
			name:           'theme dropdown'
			id:             cfg.id + 'dropdown'
			float:          true
			float_anchor:   cfg.float_anchor
			float_tie_off:  cfg.float_tie_off
			float_offset_x: cfg.float_offset_x
			float_offset_y: cfg.float_offset_y
			padding:        padding_none
			spacing:        0
			content:        [
				list_box(
					id:           lb_id
					id_scroll:    fnv1a.sum32_string(lb_id)
					min_width:    140
					max_height:   300
					data:         data
					selected_ids: [current_name]
					on_select:    fn [on_sel] (ids []string, mut e Event, mut w Window) {
						if ids.len == 0 {
							return
						}
						name := ids[0]
						t := theme_get(name) or { return }
						w.set_theme(t)
						if on_sel != unsafe { nil } {
							on_sel(name, mut e, mut w)
						}
						e.is_handled = true
					}
				),
			]
		)
	}

	color_focus := gui_theme.toggle_style.color_focus
	color_border_focus := gui_theme.toggle_style.color_border_focus

	return row(
		name:         'theme toggle'
		id:           cfg.id
		id_focus:     id_focus
		sizing:       cfg.sizing
		padding:      padding_small
		on_click:     fn [id, is_open, lb_id] (_ &Layout, mut e Event, mut w Window) {
			mut ss := state_map[string, bool](mut w, ns_select, cap_moderate)
			ss.clear()
			opening := !is_open
			ss.set(id, opening)
			if opening {
				theme_toggle_sync_highlight(lb_id, mut w)
			}
			e.is_handled = true
		}
		amend_layout: fn [id_focus, color_focus, color_border_focus] (mut layout Layout, mut w Window) {
			if w.is_focus(id_focus) {
				layout.shape.color = color_focus
				layout.shape.color_border = color_border_focus
			}
		}
		on_keydown:   fn [id, lb_id, on_sel] (mut _ Layout, mut e Event, mut w Window) {
			was_open := state_read_or[string, bool](w, ns_select, id, false)
			if !was_open {
				if e.key_code in [.space, .enter] {
					mut ss := state_map[string, bool](mut w, ns_select, cap_moderate)
					ss.set(id, true)
					theme_toggle_sync_highlight(lb_id, mut w)
					e.is_handled = true
				}
				return
			}
			mut names := gui_theme_registry.keys()
			names.sort()
			count := names.len
			if count == 0 {
				return
			}
			mut lbf := state_map[string, int](mut w, ns_list_box_focus, cap_moderate)
			current_idx := lbf.get(lb_id) or { 0 }
			action := list_core_navigate(e.key_code, count, current_idx)
			next_idx := match action {
				.dismiss {
					mut ss := state_map[string, bool](mut w, ns_select, cap_moderate)
					ss.clear()
					e.is_handled = true
					-1
				}
				.select_item {
					e.is_handled = true
					current_idx
				}
				.move_up {
					e.is_handled = true
					if current_idx > 0 { current_idx - 1 } else { 0 }
				}
				.move_down {
					e.is_handled = true
					if current_idx < count - 1 { current_idx + 1 } else { count - 1 }
				}
				.first {
					e.is_handled = true
					0
				}
				.last {
					e.is_handled = true
					count - 1
				}
				.none {
					-1
				}
			}
			if next_idx >= 0 && next_idx < count {
				lbf.set(lb_id, next_idx)
				name := names[next_idx]
				t := theme_get(name) or { return }
				w.set_theme(t)
				if on_sel != unsafe { nil } {
					on_sel(name, mut e, mut w)
				}
			}
		}
		content:      content
	)
}

// Set listbox focus index to match the current theme name.
fn theme_toggle_sync_highlight(lb_id string, mut w Window) {
	mut names := gui_theme_registry.keys()
	names.sort()
	current := gui_theme.name
	mut idx := 0
	for i, n in names {
		if n == current {
			idx = i
			break
		}
	}
	mut lbf := state_map[string, int](mut w, ns_list_box_focus, cap_moderate)
	lbf.set(lb_id, idx)
}
