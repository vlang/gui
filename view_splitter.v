module gui

const splitter_default_ratio = f32(0.5)
const splitter_double_click_frames = u64(24)

// SplitterOrientation controls how panes are arranged.
pub enum SplitterOrientation as u8 {
	horizontal
	vertical
}

// SplitterCollapsed tracks which pane is collapsed, if any.
pub enum SplitterCollapsed as u8 {
	none
	first
	second
}

// SplitterState is an app-owned persistence model for splitter state.
pub struct SplitterState {
pub:
	ratio     f32
	collapsed SplitterCollapsed = .none
}

// splitter_state_normalize normalizes state before persisting or restoring it.
pub fn splitter_state_normalize(state SplitterState) SplitterState {
	return SplitterState{
		ratio:     splitter_normalize_ratio(state.ratio)
		collapsed: state.collapsed
	}
}

// SplitterPaneCfg configures one pane of a splitter.
@[minify]
pub struct SplitterPaneCfg {
pub:
	min_size       f32
	max_size       f32
	collapsible    bool = true
	collapsed_size f32
	content        []View
}

// SplitterCfg configures a splitter component.
@[heap; minify]
pub struct SplitterCfg {
pub:
	id                    string @[required]
	id_focus              u32
	orientation           SplitterOrientation = .horizontal
	sizing                Sizing              = fill_fill
	ratio                 f32                 = splitter_default_ratio
	collapsed             SplitterCollapsed   = .none
	on_change             fn (f32, SplitterCollapsed, mut Event, mut Window) @[required]
	first                 SplitterPaneCfg @[required]
	second                SplitterPaneCfg @[required]
	handle_size           f32   = gui_theme.splitter_style.handle_size
	drag_step             f32   = gui_theme.splitter_style.drag_step
	drag_step_large       f32   = gui_theme.splitter_style.drag_step_large
	double_click_collapse bool  = true
	show_collapse_buttons bool  = true
	color_handle          Color = gui_theme.splitter_style.color_handle
	color_handle_hover    Color = gui_theme.splitter_style.color_handle_hover
	color_handle_active   Color = gui_theme.splitter_style.color_handle_active
	color_handle_border   Color = gui_theme.splitter_style.color_handle_border
	color_grip            Color = gui_theme.splitter_style.color_grip
	color_button          Color = gui_theme.splitter_style.color_button
	color_button_hover    Color = gui_theme.splitter_style.color_button_hover
	color_button_active   Color = gui_theme.splitter_style.color_button_active
	color_button_icon     Color = gui_theme.splitter_style.color_button_icon
	size_border           f32   = gui_theme.splitter_style.size_border
	radius                f32   = gui_theme.splitter_style.radius
	radius_border         f32   = gui_theme.splitter_style.radius_border
	disabled              bool
	invisible             bool
}

struct SplitterComputed {
	first_main  f32
	second_main f32
	handle_main f32
	ratio       f32
	collapsed   SplitterCollapsed
}

// split is an alias for [splitter](#splitter).
pub fn split(cfg SplitterCfg) View {
	return splitter(cfg)
}

// splitter creates a two-pane splitter with drag/keyboard/collapse controls.
pub fn splitter(cfg SplitterCfg) View {
	c := cfg

	return canvas(
		name:         'splitter'
		id:           c.id
		id_focus:     c.id_focus
		sizing:       c.sizing
		padding:      padding_none
		spacing:      0
		clip:         true
		disabled:     c.disabled
		invisible:    c.invisible
		on_keydown:   fn [c] (_ &Layout, mut e Event, mut w Window) {
			c.on_keydown(mut e, mut w)
		}
		amend_layout: fn [c] (mut layout Layout, mut w Window) {
			c.amend_layout(mut layout, mut w)
		}
		content:      [
			splitter_pane('${c.id}:pane:first', c.first.content.clone()),
			splitter_handle(c),
			splitter_pane('${c.id}:pane:second', c.second.content.clone()),
		]
	)
}

fn splitter_pane(id string, content []View) View {
	return column(
		name:    'splitter_pane'
		id:      id
		sizing:  fixed_fixed
		padding: padding_none
		spacing: 0
		clip:    true
		content: content
	)
}

fn splitter_handle(cfg SplitterCfg) View {
	mut content := []View{}
	if cfg.show_collapse_buttons && (cfg.first.collapsible || cfg.second.collapsible) {
		if cfg.first.collapsible {
			content << splitter_button(cfg, .first)
		}
		content << splitter_grip(cfg)
		if cfg.second.collapsible {
			content << splitter_button(cfg, .second)
		}
	} else {
		content << splitter_grip(cfg)
	}

	if cfg.orientation == .horizontal {
		return column(
			name:         'splitter_handle'
			id:           '${cfg.id}:handle'
			sizing:       fixed_fixed
			width:        cfg.handle_size
			padding:      padding_none
			spacing:      1
			color:        cfg.color_handle
			color_border: cfg.color_handle_border
			size_border:  cfg.size_border
			radius:       cfg.radius
			h_align:      .center
			v_align:      .middle
			on_click:     fn [cfg] (layout &Layout, mut e Event, mut w Window) {
				cfg.on_handle_click(layout, mut e, mut w)
			}
			on_hover:     fn [cfg] (mut layout Layout, mut e Event, mut w Window) {
				cfg.on_handle_hover(mut layout, mut e, mut w)
			}
			content:      content
		)
	}
	return row(
		name:         'splitter_handle'
		id:           '${cfg.id}:handle'
		sizing:       fixed_fixed
		height:       cfg.handle_size
		padding:      padding_none
		spacing:      1
		color:        cfg.color_handle
		color_border: cfg.color_handle_border
		size_border:  cfg.size_border
		radius:       cfg.radius
		h_align:      .center
		v_align:      .middle
		on_click:     fn [cfg] (layout &Layout, mut e Event, mut w Window) {
			cfg.on_handle_click(layout, mut e, mut w)
		}
		on_hover:     fn [cfg] (mut layout Layout, mut e Event, mut w Window) {
			cfg.on_handle_hover(mut layout, mut e, mut w)
		}
		content:      content
	)
}

fn splitter_grip(cfg SplitterCfg) View {
	if cfg.orientation == .horizontal {
		return rectangle(
			width:  f32_max(2, cfg.handle_size * 0.35)
			height: f32_max(14, cfg.handle_size * 2.0)
			color:  cfg.color_grip
			radius: cfg.radius_border
			sizing: fixed_fixed
		)
	}
	return rectangle(
		width:  f32_max(14, cfg.handle_size * 2.0)
		height: f32_max(2, cfg.handle_size * 0.35)
		color:  cfg.color_grip
		radius: cfg.radius_border
		sizing: fixed_fixed
	)
}

fn splitter_button(cfg SplitterCfg, target SplitterCollapsed) View {
	size := f32_max(4, cfg.handle_size - 2)
	text_style := TextStyle{
		...gui_theme.icon2
		size:  size
		color: cfg.color_button_icon
	}
	return button(
		id:          '${cfg.id}:button:${target}'
		width:       size
		height:      size
		sizing:      fixed_fixed
		padding:     padding_none
		size_border: 0
		color:       cfg.color_button
		color_hover: cfg.color_button_hover
		color_click: cfg.color_button_active
		color_focus: cfg.color_button_hover
		radius:      cfg.radius_border
		on_click:    fn [cfg, target] (layout &Layout, mut e Event, mut w Window) {
			cfg.on_button_click(target, layout, mut e, mut w)
		}
		content:     [
			text(
				text:       splitter_button_icon(cfg, target)
				text_style: text_style
			),
		]
	)
}

fn splitter_button_icon(cfg SplitterCfg, target SplitterCollapsed) string {
	current := splitter_effective_collapsed(&cfg, cfg.collapsed)
	if cfg.orientation == .horizontal {
		if target == .first {
			return if current == .first { icon_arrow_right } else { icon_arrow_left }
		}
		return if current == .second { icon_arrow_left } else { icon_arrow_right }
	}
	if target == .first {
		return if current == .first { icon_arrow_down } else { icon_arrow_up }
	}
	return if current == .second { icon_arrow_up } else { icon_arrow_down }
}

fn (cfg &SplitterCfg) on_keydown(mut e Event, mut w Window) {
	if cfg.disabled {
		return
	}
	layout := w.find_layout_by_id(cfg.id) or { return }
	main := splitter_main_size(&layout, cfg.orientation)
	handle := splitter_handle_size_from_layout(&layout, cfg.orientation, cfg.handle_size)
	available := f32_max(0, main - handle)

	mut next_ratio := splitter_clamp_ratio(cfg, available, cfg.ratio)
	mut next_collapsed := splitter_effective_collapsed(cfg, cfg.collapsed)
	mut handled := false

	is_shift := e.modifiers == .shift
	is_none := e.modifiers == .none

	match e.key_code {
		.left {
			if cfg.orientation == .horizontal && (is_none || is_shift) {
				next_collapsed = .none
				step := if is_shift { cfg.drag_step_large } else { cfg.drag_step }
				next_ratio = splitter_clamp_ratio(cfg, available, next_ratio - splitter_step(step))
				handled = true
			}
		}
		.right {
			if cfg.orientation == .horizontal && (is_none || is_shift) {
				next_collapsed = .none
				step := if is_shift { cfg.drag_step_large } else { cfg.drag_step }
				next_ratio = splitter_clamp_ratio(cfg, available, next_ratio + splitter_step(step))
				handled = true
			}
		}
		.up {
			if cfg.orientation == .vertical && (is_none || is_shift) {
				next_collapsed = .none
				step := if is_shift { cfg.drag_step_large } else { cfg.drag_step }
				next_ratio = splitter_clamp_ratio(cfg, available, next_ratio - splitter_step(step))
				handled = true
			}
		}
		.down {
			if cfg.orientation == .vertical && (is_none || is_shift) {
				next_collapsed = .none
				step := if is_shift { cfg.drag_step_large } else { cfg.drag_step }
				next_ratio = splitter_clamp_ratio(cfg, available, next_ratio + splitter_step(step))
				handled = true
			}
		}
		.home {
			if is_none && cfg.first.collapsible {
				next_collapsed = .first
				handled = true
			}
		}
		.end {
			if is_none && cfg.second.collapsible {
				next_collapsed = .second
				handled = true
			}
		}
		.enter, .space {
			if is_none {
				target := splitter_toggle_target(cfg, next_collapsed)
				if target != .none {
					next_collapsed = if next_collapsed == target {
						SplitterCollapsed.none
					} else {
						target
					}
					handled = true
				}
			}
		}
		else {}
	}

	if handled {
		cfg.emit_change(next_ratio, next_collapsed, mut e, mut w)
	}
}

fn (cfg &SplitterCfg) on_handle_click(_ &Layout, mut e Event, mut w Window) {
	if cfg.disabled {
		return
	}
	splitter_set_cursor(cfg.orientation, mut w)
	cfg.focus(mut w)

	mut runtime := w.view_state.splitter_runtime_state.get(cfg.id) or { SplitterRuntimeState{} }
	current := splitter_effective_collapsed(cfg, cfg.collapsed)
	target := splitter_toggle_target(cfg, current)
	if cfg.double_click_collapse && target != .none && runtime.last_handle_click_frame > 0
		&& e.frame_count - runtime.last_handle_click_frame <= splitter_double_click_frames {
		ratio := cfg.current_ratio(w)
		next := if current == target { SplitterCollapsed.none } else { target }
		runtime.last_handle_click_frame = 0
		w.view_state.splitter_runtime_state.set(cfg.id, runtime)
		cfg.emit_change(ratio, next, mut e, mut w)
		return
	}

	runtime.last_handle_click_frame = e.frame_count
	w.view_state.splitter_runtime_state.set(cfg.id, runtime)

	id_focus := cfg.id_focus
	w.mouse_lock(MouseLockCfg{
		mouse_move: fn [cfg] (_ &Layout, mut e Event, mut w Window) {
			cfg.on_drag_move(mut e, mut w)
		}
		mouse_up:   fn [id_focus] (_ &Layout, mut _ Event, mut w Window) {
			w.mouse_unlock()
			if id_focus > 0 {
				w.set_id_focus(id_focus)
			}
		}
	})
	e.is_handled = true
}

fn (cfg &SplitterCfg) on_drag_move(mut e Event, mut w Window) {
	if cfg.disabled {
		return
	}
	layout := w.find_layout_by_id(cfg.id) or { return }
	main := splitter_main_size(&layout, cfg.orientation)
	handle := splitter_handle_size_from_layout(&layout, cfg.orientation, cfg.handle_size)
	available := f32_max(0, main - handle)
	if available <= 0 {
		return
	}

	cursor_main := if cfg.orientation == .horizontal {
		e.mouse_x - layout.shape.x - (handle / 2)
	} else {
		e.mouse_y - layout.shape.y - (handle / 2)
	}
	ratio := splitter_clamp_ratio(cfg, available, cursor_main / available)
	splitter_set_cursor(cfg.orientation, mut w)
	cfg.emit_change(ratio, .none, mut e, mut w)
}

fn (cfg &SplitterCfg) on_handle_hover(mut layout Layout, mut e Event, mut w Window) {
	if cfg.disabled {
		return
	}
	splitter_set_cursor(cfg.orientation, mut w)
	layout.shape.color = cfg.color_handle_hover
	if e.mouse_button == .left {
		layout.shape.color = cfg.color_handle_active
	}
	e.is_handled = true
}

fn (cfg &SplitterCfg) on_button_click(target SplitterCollapsed, _ &Layout, mut e Event, mut w Window) {
	if cfg.disabled {
		return
	}
	valid_target := splitter_effective_collapsed(cfg, target)
	if valid_target == .none {
		return
	}
	ratio := cfg.current_ratio(w)
	current := splitter_effective_collapsed(cfg, cfg.collapsed)
	next := if current == valid_target { SplitterCollapsed.none } else { valid_target }
	cfg.emit_change(ratio, next, mut e, mut w)
}

fn (cfg &SplitterCfg) amend_layout(mut layout Layout, mut w Window) {
	if layout.children.len < 3 {
		return
	}

	main := splitter_main_size(&layout, cfg.orientation)
	computed := splitter_compute(cfg, main)

	if cfg.orientation == .horizontal {
		x := layout.shape.x
		y := layout.shape.y
		h := layout.shape.height
		splitter_layout_child(mut layout.children[0], x, y, computed.first_main, h, mut
			w)
		splitter_layout_child(mut layout.children[1], x + computed.first_main, y, computed.handle_main,
			h, mut w)
		splitter_layout_child(mut layout.children[2], x + computed.first_main + computed.handle_main,
			y, computed.second_main, h, mut w)
		return
	}

	x := layout.shape.x
	y := layout.shape.y
	wid := layout.shape.width
	splitter_layout_child(mut layout.children[0], x, y, wid, computed.first_main, mut
		w)
	splitter_layout_child(mut layout.children[1], x, y + computed.first_main, wid, computed.handle_main, mut
		w)
	splitter_layout_child(mut layout.children[2], x, y + computed.first_main + computed.handle_main,
		wid, computed.second_main, mut w)
}

fn splitter_layout_child(mut child Layout, x f32, y f32, width f32, height f32, mut w Window) {
	splitter_reset_positions(mut child, true, .none, 0, 0)
	child.shape.sizing = fixed_fixed
	child.shape.width = f32_max(0, width)
	child.shape.height = f32_max(0, height)
	child.shape.min_width = child.shape.width
	child.shape.max_width = child.shape.width
	child.shape.min_height = child.shape.height
	child.shape.max_height = child.shape.height
	child.shape.x = 0
	child.shape.y = 0

	layout_widths(mut child)
	layout_fill_widths(mut child)
	layout_wrap_text(mut child, mut w)
	layout_heights(mut child)
	layout_fill_heights(mut child)
	layout_adjust_scroll_offsets(mut child, mut w)
	layout_positions(mut child, x, y, &w)
	layout_amend(mut child, mut w)
}

fn splitter_reset_positions(mut layout Layout, is_root bool, parent_axis Axis, parent_old_x f32, parent_old_y f32) {
	old_x := layout.shape.x
	old_y := layout.shape.y
	if is_root {
		layout.shape.x = 0
		layout.shape.y = 0
	} else if parent_axis == .none {
		layout.shape.x = old_x - parent_old_x
		layout.shape.y = old_y - parent_old_y
	} else {
		layout.shape.x = 0
		layout.shape.y = 0
	}
	for mut child in layout.children {
		splitter_reset_positions(mut child, false, layout.shape.axis, old_x, old_y)
	}
}

fn (cfg &SplitterCfg) current_ratio(w &Window) f32 {
	layout := w.find_layout_by_id(cfg.id) or { return splitter_normalize_ratio(cfg.ratio) }
	main := splitter_main_size(&layout, cfg.orientation)
	handle := splitter_handle_size_from_layout(&layout, cfg.orientation, cfg.handle_size)
	return splitter_clamp_ratio(cfg, f32_max(0, main - handle), cfg.ratio)
}

fn (cfg &SplitterCfg) emit_change(ratio f32, collapsed SplitterCollapsed, mut e Event, mut w Window) {
	state := splitter_state_normalize(SplitterState{
		ratio:     ratio
		collapsed: collapsed
	})
	cfg.on_change(state.ratio, state.collapsed, mut e, mut w)
	cfg.focus(mut w)
	e.is_handled = true
}

fn (cfg &SplitterCfg) focus(mut w Window) {
	if cfg.id_focus > 0 {
		w.set_id_focus(cfg.id_focus)
	}
}

fn splitter_compute(cfg &SplitterCfg, main_size f32) SplitterComputed {
	handle := splitter_handle_size(cfg.handle_size, main_size)
	available := f32_max(0, main_size - handle)
	mut ratio := splitter_clamp_ratio(cfg, available, cfg.ratio)
	collapsed := splitter_effective_collapsed(cfg, cfg.collapsed)

	mut first := f32(0)
	mut second := f32(0)
	match collapsed {
		.first {
			first, second = splitter_collapsed_first(cfg, available)
		}
		.second {
			first, second = splitter_collapsed_second(cfg, available)
		}
		.none {
			first = splitter_clamp_first_size(cfg, available, ratio * available)
			second = f32_max(0, available - first)
			ratio = if available > 0 { first / available } else { splitter_default_ratio }
		}
	}
	return SplitterComputed{
		first_main:  first
		second_main: second
		handle_main: handle
		ratio:       ratio
		collapsed:   collapsed
	}
}

fn splitter_collapsed_first(cfg &SplitterCfg, available f32) (f32, f32) {
	first_target := f32_clamp(cfg.first.collapsed_size, 0, available)
	mut second_min := f32_max(0, cfg.second.min_size)
	second_max := splitter_limit_max(cfg.second.max_size, available)
	if second_min > second_max {
		second_min = second_max
	}
	mut second := f32_clamp(available - first_target, second_min, second_max)
	mut first := f32_max(0, available - second)
	first = f32_min(first, splitter_limit_max(cfg.first.max_size, available))
	second = f32_max(0, available - first)
	return first, second
}

fn splitter_collapsed_second(cfg &SplitterCfg, available f32) (f32, f32) {
	second_target := f32_clamp(cfg.second.collapsed_size, 0, available)
	mut first_min := f32_max(0, cfg.first.min_size)
	first_max := splitter_limit_max(cfg.first.max_size, available)
	if first_min > first_max {
		first_min = first_max
	}
	first := f32_clamp(available - second_target, first_min, first_max)
	mut second := f32_max(0, available - first)
	second = f32_min(second, splitter_limit_max(cfg.second.max_size, available))
	return f32_max(0, available - second), f32_max(0, second)
}

fn splitter_main_size(layout &Layout, orientation SplitterOrientation) f32 {
	return if orientation == .horizontal { layout.shape.width } else { layout.shape.height }
}

fn splitter_handle_size_from_layout(layout &Layout, orientation SplitterOrientation, fallback f32) f32 {
	if layout.children.len > 1 {
		handle := layout.children[1]
		return if orientation == .horizontal { handle.shape.width } else { handle.shape.height }
	}
	return fallback
}

fn splitter_handle_size(handle_size f32, main_size f32) f32 {
	size := f32_max(1, handle_size)
	if main_size <= 0 {
		return size
	}
	return f32_min(size, main_size)
}

fn splitter_clamp_ratio(cfg &SplitterCfg, available f32, ratio f32) f32 {
	if available <= 0 {
		return splitter_default_ratio
	}
	target := splitter_normalize_ratio(ratio) * available
	first := splitter_clamp_first_size(cfg, available, target)
	return first / available
}

fn splitter_clamp_first_size(cfg &SplitterCfg, available f32, target f32) f32 {
	mut lower, mut upper := splitter_bounds(cfg, available)
	lower = f32_clamp(lower, 0, available)
	upper = f32_clamp(upper, 0, available)
	if lower <= upper {
		return f32_clamp(target, lower, upper)
	}
	return f32_clamp(target, upper, lower)
}

fn splitter_bounds(cfg &SplitterCfg, available f32) (f32, f32) {
	mut first_min := f32_max(0, cfg.first.min_size)
	first_max := splitter_limit_max(cfg.first.max_size, available)
	if first_min > first_max {
		first_min = first_max
	}

	mut second_min := f32_max(0, cfg.second.min_size)
	second_max := splitter_limit_max(cfg.second.max_size, available)
	if second_min > second_max {
		second_min = second_max
	}

	lower := f32_max(first_min, available - second_max)
	upper := f32_min(first_max, available - second_min)
	return lower, upper
}

fn splitter_limit_max(value f32, available f32) f32 {
	if value > 0 {
		return f32_clamp(value, 0, available)
	}
	return available
}

fn splitter_normalize_ratio(ratio f32) f32 {
	return f32_clamp(ratio, 0, 1)
}

fn splitter_toggle_target(cfg &SplitterCfg, current SplitterCollapsed) SplitterCollapsed {
	active := splitter_effective_collapsed(cfg, current)
	if active != .none {
		return active
	}
	if cfg.first.collapsible {
		return .first
	}
	if cfg.second.collapsible {
		return .second
	}
	return .none
}

fn splitter_step(step f32) f32 {
	return if step > 0 { step } else { f32(0.02) }
}

fn splitter_effective_collapsed(cfg &SplitterCfg, collapsed SplitterCollapsed) SplitterCollapsed {
	return match collapsed {
		.first {
			if cfg.first.collapsible {
				SplitterCollapsed.first
			} else {
				SplitterCollapsed.none
			}
		}
		.second {
			if cfg.second.collapsible {
				SplitterCollapsed.second
			} else {
				SplitterCollapsed.none
			}
		}
		.none {
			SplitterCollapsed.none
		}
	}
}

fn splitter_set_cursor(orientation SplitterOrientation, mut w Window) {
	if orientation == .horizontal {
		w.set_mouse_cursor_ew()
	} else {
		w.set_mouse_cursor_ns()
	}
}
