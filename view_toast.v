module gui

import time

// ToastSeverity controls the accent bar color for a toast.
pub enum ToastSeverity as u8 {
	info
	success
	warning
	error
}

// ToastCfg configures a toast notification shown via
// w.toast(ToastCfg{...}).
pub struct ToastCfg {
pub:
	title        string
	body         string
	severity     ToastSeverity
	duration     time.Duration = 3 * time.second
	action_label string
	on_action    fn (mut Window) = unsafe { nil }
}

// ToastNotification is an active toast in the queue.
struct ToastNotification {
mut:
	id        u64
	cfg       ToastCfg
	anim_frac f32 // 0=collapsed, 1=full height
	phase     ToastPhase
	hovered   bool
}

enum ToastPhase as u8 {
	entering
	visible
	exiting
}

// toast_container_view builds a floating column holding all
// visible toasts. Called from layout_arrange when toasts exist.
fn toast_container_view(window &Window) View {
	style := gui_theme.toast_style
	anchor := style.anchor

	float_anchor, float_tie_off := match anchor {
		.top_left { FloatAttach.top_left, FloatAttach.top_left }
		.top_right { FloatAttach.top_right, FloatAttach.top_right }
		.bottom_left { FloatAttach.bottom_left, FloatAttach.bottom_left }
		.bottom_right { FloatAttach.bottom_right, FloatAttach.bottom_right }
	}

	offset_x := match anchor {
		.top_left, .bottom_left { style.margin }
		.top_right, .bottom_right { -style.margin }
	}
	offset_y := match anchor {
		.top_left, .top_right { style.margin }
		.bottom_left, .bottom_right { -style.margin }
	}

	// Build toast views — newest at anchor edge.
	at_bottom := anchor == .bottom_left || anchor == .bottom_right
	mut content := []View{cap: window.toasts.len}
	if at_bottom {
		// Bottom anchor: newest last so it appears at the bottom
		for i := 0; i < window.toasts.len; i++ {
			toast := window.toasts[i]
			if toast.anim_frac > 0 {
				content << toast_item_view(toast, style)
			}
		}
	} else {
		// Top anchor: newest first so it appears at the top
		for i := window.toasts.len - 1; i >= 0; i-- {
			toast := window.toasts[i]
			if toast.anim_frac > 0 {
				content << toast_item_view(toast, style)
			}
		}
	}

	return column(
		name:           'toast_container'
		float:          true
		float_anchor:   float_anchor
		float_tie_off:  float_tie_off
		float_offset_x: offset_x
		float_offset_y: offset_y
		sizing:         fit_fit
		spacing:        style.spacing
		padding:        padding_none
		color:          color_transparent
		size_border:    0
		content:        content
	)
}

// toast_item_view builds a single toast row with accent bar,
// text, and dismiss/action buttons.
fn toast_item_view(toast ToastNotification, style ToastStyle) View {
	accent_color := match toast.cfg.severity {
		.info { style.color_info }
		.success { style.color_success }
		.warning { style.color_warning }
		.error { style.color_error }
	}

	frac := toast.anim_frac
	toast_id := toast.id

	mut body_content := []View{cap: 4}

	// Title
	if toast.cfg.title.len > 0 {
		body_content << text(
			text:       toast.cfg.title
			text_style: style.title_style
		)
	}

	// Body
	if toast.cfg.body.len > 0 {
		body_content << text(
			text:       toast.cfg.body
			text_style: style.text_style
			mode:       .multiline
		)
	}

	// Action + dismiss button row
	mut btn_content := []View{cap: 2}
	if toast.cfg.action_label.len > 0 {
		action_label := toast.cfg.action_label
		on_action := toast.cfg.on_action
		btn_content << button(
			content:      [
				text(
					text:       action_label
					text_style: TextStyle{
						...style.text_style
						color: accent_color
					}
				),
			]
			color:        color_transparent
			color_border: color_transparent
			size_border:  0
			on_click:     fn [toast_id, on_action] (_ &Layout, mut _ Event, mut w Window) {
				if on_action != unsafe { nil } {
					on_action(mut w)
				}
				w.toast_dismiss(toast_id)
			}
		)
	}
	// Dismiss button (×)
	btn_content << button(
		content:      [
			text(
				text:       '\u00d7'
				text_style: style.text_style
			),
		]
		color:        color_transparent
		color_border: color_transparent
		size_border:  0
		on_click:     fn [toast_id] (_ &Layout, mut _ Event, mut w Window) {
			w.toast_dismiss(toast_id)
		}
	)

	return row(
		name:         'toast_item'
		width:        style.width
		sizing:       fixed_fit
		color:        style.color
		color_border: style.color_border
		size_border:  style.size_border
		radius:       style.radius
		shadow:       style.shadow
		padding:      padding_none
		clip:         true
		opacity:      frac
		on_hover:     fn [toast_id] (mut _ Layout, mut e Event, mut w Window) {
			toast_set_hovered(mut w, toast_id, true)
			e.is_handled = true
		}
		amend_layout: fn [frac] (mut layout Layout, mut _ Window) {
			// Scale height by anim_frac for enter/exit
			if frac < 1.0 {
				layout.shape.height = layout.shape.height * frac
			}
		}
		content:      [
			// Accent bar
			column(
				width:        style.accent_width
				color:        accent_color
				color_border: color_transparent
				padding:      padding_none
				sizing:       Sizing{.fixed, .fill}
				size_border:  0
				radius:       0
			),
			// Body column (title + body text)
			column(
				padding:     style.padding
				sizing:      fill_fit
				spacing:     gui_theme.spacing_small
				color:       color_transparent
				size_border: 0
				content:     body_content
			),
			// Buttons column (action + dismiss)
			column(
				padding:     padding(4, 4, 0, 0)
				v_align:     .top
				spacing:     0
				color:       color_transparent
				size_border: 0
				content:     btn_content
			),
		]
	)
}

// toast_set_hovered marks a toast as hovered (pauses
// auto-dismiss). Called from on_hover.
fn toast_set_hovered(mut w Window, id u64, hovered bool) {
	for i, t in w.toasts {
		if t.id == id {
			w.toasts[i].hovered = hovered
			return
		}
	}
}

// toast_start_enter begins the enter animation for a toast.
fn toast_start_enter(mut w Window, id u64) {
	anim_id := 'toast:enter:${id}'
	w.animation_add(mut TweenAnimation{
		id:       anim_id
		from:     0.0
		to:       1.0
		duration: 200 * time.millisecond
		easing:   ease_out_cubic
		on_value: fn [id] (v f32, mut w Window) {
			for i, t in w.toasts {
				if t.id == id {
					w.toasts[i].anim_frac = v
					return
				}
			}
		}
		on_done:  fn [id] (mut w Window) {
			for i, t in w.toasts {
				if t.id == id {
					w.toasts[i].phase = .visible
					toast_start_dismiss_timer(mut w, id)
					return
				}
			}
		}
	})
}

// toast_start_dismiss_timer starts the auto-dismiss delay
// animation. Hover pauses by re-checking hovered state.
fn toast_start_dismiss_timer(mut w Window, id u64) {
	dur := toast_duration(w, id)
	if dur <= 0 {
		return
	}
	anim_id := 'toast:dismiss:${id}'
	w.animation_add(mut Animate{
		id:       anim_id
		delay:    dur
		callback: fn [id] (mut _ Animate, mut w Window) {
			// If hovered, restart timer
			for t in w.toasts {
				if t.id == id {
					if t.hovered {
						// Reset hover flag and restart timer
						toast_set_hovered(mut w, id, false)
						toast_start_dismiss_timer(mut w, id)
						return
					}
					break
				}
			}
			toast_start_exit(mut w, id)
		}
	})
}

// toast_duration returns the configured duration for a toast, or 0.
fn toast_duration(w &Window, id u64) time.Duration {
	for t in w.toasts {
		if t.id == id {
			return t.cfg.duration
		}
	}
	return 0
}

// toast_start_exit begins the exit animation for a toast.
fn toast_start_exit(mut w Window, id u64) {
	// Already exiting?
	for t in w.toasts {
		if t.id == id && t.phase == .exiting {
			return
		}
	}
	for i, t in w.toasts {
		if t.id == id {
			w.toasts[i].phase = .exiting
			break
		}
	}
	anim_id := 'toast:exit:${id}'
	w.animation_add(mut TweenAnimation{
		id:       anim_id
		from:     1.0
		to:       0.0
		duration: 200 * time.millisecond
		easing:   ease_in_cubic
		on_value: fn [id] (v f32, mut w Window) {
			for i, t in w.toasts {
				if t.id == id {
					w.toasts[i].anim_frac = v
					return
				}
			}
		}
		on_done:  fn [id] (mut w Window) {
			toast_remove(mut w, id)
		}
	})
}

// toast_remove removes a toast from the queue by id and
// triggers a layout rebuild.
fn toast_remove(mut w Window, id u64) {
	for i, t in w.toasts {
		if t.id == id {
			w.toasts.delete(i)
			w.update_window()
			return
		}
	}
}

// toast_enforce_max_visible evicts the oldest toasts when
// the queue exceeds max_visible.
fn toast_enforce_max_visible(mut w Window) {
	max := gui_theme.toast_style.max_visible
	if max <= 0 {
		return
	}
	mut exiting := 0
	for t in w.toasts {
		if t.phase == .exiting {
			exiting++
		}
	}
	visible := w.toasts.len - exiting
	if visible > max {
		mut evicted := 0
		for t in w.toasts {
			if t.phase != .exiting {
				toast_start_exit(mut w, t.id)
				evicted++
				if visible - evicted <= max {
					break
				}
			}
		}
	}
}
