module gui

// view_command_palette.v implements a keyboard-first command
// palette with fuzzy search, result ranking, and backdrop.
// The palette does not own a hotkey — the caller toggles it
// via command_palette_show / command_palette_toggle.

pub struct CommandPaletteItem {
pub:
	id       string @[required]
	label    string @[required]
	detail   string // shortcut hint e.g. "Ctrl+S"
	icon     string
	group    string // category header
	disabled bool
}

@[minify]
pub struct CommandPaletteCfg {
pub:
	id              string = '__cmd_palette__'
	items           []CommandPaletteItem
	on_action       fn (string, mut Event, mut Window) @[required]
	on_dismiss      fn (mut Window) = unsafe { nil }
	placeholder     string          = 'Type a command...'
	text_style      TextStyle       = gui_theme.command_palette_style.text_style
	detail_style    TextStyle       = gui_theme.command_palette_style.detail_style
	color           Color           = gui_theme.command_palette_style.color
	color_border    Color           = gui_theme.command_palette_style.color_border
	color_highlight Color           = gui_theme.command_palette_style.color_highlight
	size_border     f32             = gui_theme.command_palette_style.size_border
	radius          f32             = gui_theme.command_palette_style.radius
	width           f32             = gui_theme.command_palette_style.width
	max_height      f32             = gui_theme.command_palette_style.max_height
	backdrop_color  Color           = gui_theme.command_palette_style.backdrop_color
	id_focus        u32 @[required]
	id_scroll       u32
}

// command_palette creates the palette view. Include in view tree;
// hidden unless command_palette_show was called.
pub fn (mut window Window) command_palette(cfg CommandPaletteCfg) View {
	visible := state_read_or[string, bool](&window, ns_cmd_palette, cfg.id, false)
	if !visible {
		return row(name: 'cmd_palette hidden')
	}

	query := state_read_or[string, string](&window, ns_cmd_palette_query, cfg.id, '')
	highlighted := state_read_or[string, int](&window, ns_cmd_palette_highlight, cfg.id,
		0)

	// Convert to core items.
	mut core_items := []ListCoreItem{cap: cfg.items.len}
	for item in cfg.items {
		core_items << cmd_palette_item_to_core(item)
	}

	// Filter + rank.
	prepared := list_core_prepare(core_items, query, highlighted)
	filtered := prepared.items
	filtered_ids := prepared.ids
	hl := prepared.hl

	// Virtualization.
	row_h := list_core_row_height_estimate(cfg.text_style, padding_two_five)
	scroll_y := if cfg.id_scroll > 0 {
		state_read_or[u32, f32](&window, ns_scroll_y, cfg.id_scroll, f32(0))
	} else {
		f32(0)
	}
	first, last := list_core_visible_range(filtered.len, row_h, cfg.max_height, scroll_y)

	on_action := cfg.on_action
	palette_id := cfg.id
	on_dismiss := cfg.on_dismiss

	core_cfg := ListCoreCfg{
		text_style:      cfg.text_style
		detail_style:    cfg.detail_style
		color_highlight: cfg.color_highlight
		color_hover:     cfg.color_highlight
		color_selected:  cfg.color_highlight
		padding_item:    padding_two_five
		show_details:    true
		show_icons:      true
		on_item_click:   fn [on_action, palette_id, on_dismiss] (item_id string, _ int, mut e Event, mut w Window) {
			on_action(item_id, mut e, mut w)
			command_palette_dismiss(palette_id, mut w)
			if on_dismiss != unsafe { nil } {
				on_dismiss(mut w)
			}
		}
	}

	result_views := list_core_views(filtered, core_cfg, first, last, hl, [], row_h)

	// Build layout.
	// Backdrop column fills screen, centered card floats within.
	return column(
		name:     'cmd_palette backdrop'
		color:    cfg.backdrop_color
		sizing:   fill_fill
		float:    true
		v_align:  .top
		h_align:  .center
		padding:  padding(60, 0, 0, 0)
		on_click: fn [palette_id, on_dismiss] (_ &Layout, mut e Event, mut w Window) {
			command_palette_dismiss(palette_id, mut w)
			if on_dismiss != unsafe { nil } {
				on_dismiss(mut w)
			}
			e.is_handled = true
		}
		content:  [
			column(
				name:         'cmd_palette card'
				id:           cfg.id
				id_focus:     cfg.id_focus
				color:        cfg.color
				color_border: cfg.color_border
				size_border:  cfg.size_border
				radius:       cfg.radius
				width:        cfg.width
				padding:      padding_none
				spacing:      0
				sizing:       fixed_fit
				on_keydown:   make_palette_on_keydown(palette_id, on_action, on_dismiss,
					filtered_ids)
				on_click:     fn (_ &Layout, mut e Event, mut _ Window) {
					// Prevent backdrop click when clicking card.
					e.is_handled = true
				}
				content:      [
					row(
						name:    'cmd_palette search'
						padding: padding_small
						sizing:  fill_fit
						content: [
							input(
								id:              cfg.id + '.input'
								text:            query
								placeholder:     cfg.placeholder
								text_style:      cfg.text_style
								id_focus:        cfg.id_focus
								sizing:          fill_fit
								on_text_changed: make_palette_on_text_changed(cfg.id)
							),
						]
					),
					column(
						name:       'cmd_palette results'
						id_scroll:  cfg.id_scroll
						max_height: cfg.max_height
						sizing:     fill_fit
						padding:    padding_none
						spacing:    0
						clip:       true
						content:    result_views
					),
				]
			),
		]
	)
}

// command_palette_show makes the palette visible and focuses input.
pub fn command_palette_show(id string, id_focus u32, mut w Window) {
	mut ss := state_map[string, bool](mut w, ns_cmd_palette, cap_moderate)
	ss.set(id, true)
	mut sq := state_map[string, string](mut w, ns_cmd_palette_query, cap_moderate)
	sq.set(id, '')
	mut sh := state_map[string, int](mut w, ns_cmd_palette_highlight, cap_moderate)
	sh.set(id, 0)
	w.set_id_focus(id_focus)
	w.update_window()
}

// command_palette_dismiss hides the palette.
pub fn command_palette_dismiss(id string, mut w Window) {
	mut ss := state_map[string, bool](mut w, ns_cmd_palette, cap_moderate)
	ss.set(id, false)
	mut sq := state_map[string, string](mut w, ns_cmd_palette_query, cap_moderate)
	sq.set(id, '')
	mut sh := state_map[string, int](mut w, ns_cmd_palette_highlight, cap_moderate)
	sh.set(id, 0)
	w.update_window()
}

// command_palette_toggle toggles palette visibility.
pub fn command_palette_toggle(id string, id_focus u32, mut w Window) {
	visible := state_read_or[string, bool](w, ns_cmd_palette, id, false)
	if visible {
		command_palette_dismiss(id, mut w)
	} else {
		command_palette_show(id, id_focus, mut w)
	}
}

// command_palette_is_visible returns whether the palette is showing.
pub fn command_palette_is_visible(w &Window, id string) bool {
	return state_read_or[string, bool](w, ns_cmd_palette, id, false)
}

fn cmd_palette_item_to_core(item CommandPaletteItem) ListCoreItem {
	return ListCoreItem{
		id:       item.id
		label:    item.label
		detail:   item.detail
		icon:     item.icon
		group:    item.group
		disabled: item.disabled
	}
}

fn make_palette_on_text_changed(palette_id string) fn (&Layout, string, mut Window) {
	return fn [palette_id] (_ &Layout, new_text string, mut w Window) {
		mut sq := state_map[string, string](mut w, ns_cmd_palette_query, cap_moderate)
		sq.set(palette_id, new_text)
		mut sh := state_map[string, int](mut w, ns_cmd_palette_highlight, cap_moderate)
		sh.set(palette_id, 0)
		w.update_window()
	}
}

fn make_palette_on_keydown(palette_id string, on_action fn (string, mut Event, mut Window), on_dismiss fn (mut Window), filtered_ids []string) fn (mut Layout, mut Event, mut Window) {
	return fn [palette_id, on_action, on_dismiss, filtered_ids] (mut _ Layout, mut e Event, mut w Window) {
		palette_on_keydown(palette_id, on_action, on_dismiss, filtered_ids, mut e, mut
			w)
	}
}

fn palette_on_keydown(palette_id string, on_action fn (string, mut Event, mut Window), on_dismiss fn (mut Window), filtered_ids []string, mut e Event, mut w Window) {
	if e.key_code == .escape {
		command_palette_dismiss(palette_id, mut w)
		if on_dismiss != unsafe { nil } {
			on_dismiss(mut w)
		}
		e.is_handled = true
		return
	}

	item_count := filtered_ids.len
	mut sh := state_map[string, int](mut w, ns_cmd_palette_highlight, cap_moderate)
	cur := sh.get(palette_id) or { 0 }
	action := list_core_navigate(e.key_code, item_count, cur)

	if action == .select_item {
		if cur >= 0 && cur < item_count {
			on_action(filtered_ids[cur], mut e, mut w)
			command_palette_dismiss(palette_id, mut w)
			if on_dismiss != unsafe { nil } {
				on_dismiss(mut w)
			}
		}
		e.is_handled = true
		return
	}
	next, changed := list_core_apply_nav(action, cur, item_count)
	if changed {
		sh.set(palette_id, next)
		w.update_window()
		e.is_handled = true
	}
}
