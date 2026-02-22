module gui

import time

pub enum SidebarSide as u8 {
	left
	right
}

struct SidebarRuntimeState {
mut:
	prev_open   bool
	anim_frac   f32
	initialized bool
}

@[minify]
pub struct SidebarCfg {
	A11yCfg
pub:
	id             string @[required]
	open           bool
	width          f32 = 250
	content        []View @[required]
	sizing         Sizing     = fixed_fill
	color          Color      = gui_theme.color_panel
	shadow         &BoxShadow = unsafe { nil }
	radius         f32
	padding        Padding       = gui_theme.container_style.padding
	clip           bool          = true
	side           SidebarSide   = .left
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
pub fn sidebar(mut w Window, cfg SidebarCfg) View {
	if cfg.invisible {
		return invisible_container_view()
	}

	anim_w := sidebar_animated_width(mut w, cfg)
	pad_w := cfg.padding.left + cfg.padding.right
	pad := if anim_w > pad_w { cfg.padding } else { Padding{} }

	return column(
		name:       'sidebar'
		id:         cfg.id
		sizing:     cfg.sizing
		width:      anim_w
		padding:    pad
		color:      cfg.color
		shadow:     cfg.shadow
		radius:     cfg.radius
		clip:       cfg.clip
		disabled:   cfg.disabled
		a11y_role:  .group
		a11y_label: a11y_label(cfg.a11y_label, cfg.id)
		content:    cfg.content
	)
}

fn sidebar_animated_width(mut w Window, cfg SidebarCfg) f32 {
	mut sm := state_map[string, SidebarRuntimeState](mut w, ns_sidebar, cap_few)
	mut rt := sm.get(cfg.id) or { SidebarRuntimeState{} }

	target := if cfg.open { f32(1) } else { f32(0) }

	if !rt.initialized {
		rt.anim_frac = target
		rt.prev_open = cfg.open
		rt.initialized = true
		sm.set(cfg.id, rt)
		return cfg.width * target
	}

	if cfg.open != rt.prev_open {
		rt.prev_open = cfg.open
		sm.set(cfg.id, rt)
		sidebar_start_animation(cfg.id, rt.anim_frac, target, cfg.spring, cfg.tween_duration,
			cfg.tween_easing, mut w)
	}

	return cfg.width * f32_max(0, rt.anim_frac)
}

fn sidebar_start_animation(sidebar_id string, from f32, to f32, spring_cfg SpringCfg, tween_dur time.Duration, tween_easing EasingFn, mut w Window) {
	anim_id := 'sidebar:${sidebar_id}'
	id := sidebar_id
	if tween_dur > 0 {
		w.animation_add(mut TweenAnimation{
			id:       anim_id
			from:     from
			to:       to
			duration: tween_dur
			easing:   tween_easing
			on_value: fn [id] (v f32, mut w Window) {
				mut sm := state_map[string, SidebarRuntimeState](mut w, ns_sidebar, cap_few)
				mut rt := sm.get(id) or { SidebarRuntimeState{} }
				rt.anim_frac = v
				sm.set(id, rt)
			}
		})
	} else {
		mut spring := SpringAnimation{
			id:       anim_id
			config:   spring_cfg
			on_value: fn [id] (v f32, mut w Window) {
				mut sm := state_map[string, SidebarRuntimeState](mut w, ns_sidebar, cap_few)
				mut rt := sm.get(id) or { SidebarRuntimeState{} }
				rt.anim_frac = v
				sm.set(id, rt)
			}
		}
		spring.spring_to(from, to)
		w.animation_add(mut spring)
	}
}
