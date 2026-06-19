module gui

import time

struct SidebarRuntimeState {
mut:
	prev_open      bool
	current_frac   f32
	tween_from     f32
	tween_to       f32
	tween_progress f32
	tween_active   bool
	initialized    bool
}

@[minify]
pub struct SidebarCfg {
	A11yCfg
pub:
	id      string @[required]
	open    bool
	width   f32 = 250
	content []View @[required]
	sizing  Sizing     = fixed_fill
	color   Color      = gui_theme.color_panel
	shadow  &BoxShadow = unsafe { nil }
	radius  f32
	padding Padding = gui_theme.container_style.padding
	clip    bool    = true
	// Animation: tween wins if tween_duration > 0; set it
	// to 0 to use spring instead. They are mutually exclusive.
	spring         SpringCfg     = spring_stiff
	tween_duration time.Duration = 300 * time.millisecond
	tween_easing   EasingFn      = ease_in_out_cubic
	disabled       bool
	invisible      bool
}

// sidebar creates an animated panel that slides in/out.
// Requires mut Window to read/write animation state.
// Width animates between 0 and cfg.width during the view
// rebuild so a parent row redistributes space naturally.
pub fn (mut w Window) sidebar(cfg SidebarCfg) View {
	if cfg.invisible {
		return invisible_container_view()
	}

	anim_w := sidebar_animated_width(mut w, cfg)
	// Snap padding to zero when animated width is too narrow
	// to contain horizontal padding; prevents layout overflow.
	pad_w := cfg.padding.left + cfg.padding.right
	pad := if anim_w > pad_w { cfg.padding } else { Padding{} }

	return column(
		name:             'sidebar'
		id:               cfg.id
		sizing:           cfg.sizing
		width:            anim_w
		padding:          pad
		color:            cfg.color
		shadow:           cfg.shadow
		radius:           cfg.radius
		clip:             cfg.clip
		disabled:         cfg.disabled
		a11y_role:        .group
		a11y_label:       a11y_label(cfg.a11y_label, cfg.id)
		a11y_description: cfg.a11y_description
		content:          cfg.content
	)
}

fn sidebar_animated_width(mut w Window, cfg SidebarCfg) f32 {
	mut sm := state_map[string, SidebarRuntimeState](mut w, ns_sidebar, cap_few)
	mut rt := sm.get(cfg.id) or { SidebarRuntimeState{} }

	target := if cfg.open { f32(1) } else { f32(0) }

	if !rt.initialized {
		rt.current_frac = target
		rt.tween_from = target
		rt.tween_to = target
		rt.tween_progress = 1
		rt.tween_active = false
		rt.prev_open = cfg.open
		rt.initialized = true
		sm.set(cfg.id, rt)
		return cfg.width * target
	}

	current_frac := sidebar_resolve_fraction(rt, cfg.tween_easing)
	if cfg.open != rt.prev_open {
		rt.prev_open = cfg.open
		rt.current_frac = current_frac
		sm.set(cfg.id, rt)
		sidebar_start_animation(cfg.id, current_frac, target, cfg.spring, cfg.tween_duration, mut w)
	}

	rt = sm.get(cfg.id) or { rt }
	return cfg.width * f32_max(0, sidebar_resolve_fraction(rt, cfg.tween_easing))
}

fn sidebar_resolve_fraction(rt SidebarRuntimeState, easing EasingFn) f32 {
	if rt.tween_active {
		progress := f32_clamp(rt.tween_progress, 0, 1)
		return lerp(rt.tween_from, rt.tween_to, easing(progress))
	}
	return rt.current_frac
}

fn sidebar_on_spring_value(id string) fn (f32, mut Window) {
	return fn [id] (v f32, mut w Window) {
		mut sm := state_map[string, SidebarRuntimeState](mut w, ns_sidebar, cap_few)
		mut rt := sm.get(id) or { SidebarRuntimeState{} }
		rt.current_frac = v
		rt.tween_active = false
		sm.set(id, rt)
	}
}

fn sidebar_on_tween_progress(id string) fn (f32, mut Window) {
	return fn [id] (progress f32, mut w Window) {
		mut sm := state_map[string, SidebarRuntimeState](mut w, ns_sidebar, cap_few)
		mut rt := sm.get(id) or { SidebarRuntimeState{} }
		rt.tween_progress = f32_clamp(progress, 0, 1)
		rt.tween_active = rt.tween_progress < 1
		if !rt.tween_active {
			rt.current_frac = rt.tween_to
		}
		sm.set(id, rt)
	}
}

fn sidebar_start_animation(sidebar_id string, from f32, to f32, spring_cfg SpringCfg, tween_dur time.Duration, mut w Window) {
	w.animation_add_from_layout(fn [mut w, sidebar_id, from, to, spring_cfg, tween_dur] () {
		anim_id := 'sidebar:${sidebar_id}'
		if tween_dur > 0 {
			mut sm := state_map[string, SidebarRuntimeState](mut w, ns_sidebar, cap_few)
			mut rt := sm.get(sidebar_id) or { SidebarRuntimeState{} }
			rt.current_frac = from
			rt.tween_from = from
			rt.tween_to = to
			rt.tween_progress = 0
			rt.tween_active = true
			sm.set(sidebar_id, rt)
			w.animation_add(mut TweenAnimation{
				id:       anim_id
				from:     0
				to:       1
				duration: tween_dur
				easing:   ease_linear
				on_value: sidebar_on_tween_progress(sidebar_id)
			})
		} else {
			mut spring := SpringAnimation{
				id:       anim_id
				config:   spring_cfg
				on_value: sidebar_on_spring_value(sidebar_id)
			}
			spring.spring_to(from, to)
			w.animation_add(mut spring)
		}
	}) or { panic(err) }
}
