module gui

import time

// HeroSnapshot captures element state for hero transitions
struct HeroSnapshot {
	x       f32
	y       f32
	width   f32
	height  f32
	opacity f32
}

// HeroTransitionCfg configures hero transition
pub struct HeroTransitionCfg {
pub:
	duration time.Duration = 300 * time.millisecond
	easing   EasingFn      = ease_out_cubic
}

// HeroTransition animates elements between views
pub struct HeroTransition implements Animation {
pub:
	id       string          = '__hero_transition__'
	duration time.Duration   = 300 * time.millisecond
	easing   EasingFn        = ease_out_cubic
	on_done  fn (mut Window) = unsafe { nil }
mut:
	delay    time.Duration
	start    time.Time
	stopped  bool
	outgoing map[string]HeroSnapshot // hero id -> snapshot
	incoming map[string]HeroSnapshot // captured after view switch
	progress f32
}

// transition_to_view switches view with hero animation
pub fn (mut w Window) transition_to_view(gen fn (mut Window) View, cfg HeroTransitionCfg) {
	// Capture outgoing hero elements
	outgoing := capture_hero_snapshots(w.layout)

	// Switch to new view
	w.lock()
	w.view_state.clear(mut w)
	w.view_generator = gen
	w.unlock()

	// Generate new layout to capture incoming positions
	mut view := gen(mut w)
	mut new_layout := generate_layout(mut view, mut w)
	layouts := layout_arrange(mut new_layout, mut w)
	temp_layout := Layout{
		shape:    &Shape{
			color: color_transparent
		}
		children: layouts
	}
	incoming := capture_hero_snapshots(temp_layout)

	mut transition := &HeroTransition{
		duration: cfg.duration
		easing:   cfg.easing
		outgoing: outgoing
		incoming: incoming
	}
	w.animation_add(mut transition)
	w.update_window()
}

// capture_hero_snapshots finds all hero-marked elements
fn capture_hero_snapshots(layout Layout) map[string]HeroSnapshot {
	mut snapshots := map[string]HeroSnapshot{}
	capture_heroes_recursive(layout, mut snapshots)
	return snapshots
}

fn capture_heroes_recursive(layout Layout, mut snapshots map[string]HeroSnapshot) {
	if layout.shape.hero && layout.shape.id != '' {
		snapshots[layout.shape.id] = HeroSnapshot{
			x:       layout.shape.x
			y:       layout.shape.y
			width:   layout.shape.width
			height:  layout.shape.height
			opacity: 1.0
		}
	}
	for child in layout.children {
		capture_heroes_recursive(child, mut snapshots)
	}
}

fn update_hero_transition(mut ht HeroTransition, mut w Window, mut deferred []AnimationCallback) bool {
	if ht.stopped {
		return false
	}

	elapsed := time.since(ht.start)
	if elapsed < ht.delay {
		return false
	}

	anim_elapsed := elapsed - ht.delay
	if anim_elapsed >= ht.duration {
		ht.progress = 1.0
		ht.stopped = true
		if ht.on_done != unsafe { nil } {
			deferred << ht.on_done
		}
		return true
	}

	progress := f32(anim_elapsed) / f32(ht.duration)
	ht.progress = ht.easing(progress)
	return true
}

// apply_hero_transition modifies layout during render for hero effect
fn apply_hero_transition(mut layout Layout, w &Window) {
	for animation in w.animations {
		if animation.id == '__hero_transition__' {
			if animation is HeroTransition {
				if animation.stopped {
					return
				}
				apply_hero_recursive(mut layout, animation.progress, animation.outgoing,
					animation.incoming)
				return
			}
		}
	}
}

// propagate_opacity sets opacity on element and all descendants
fn propagate_opacity(mut layout Layout, opacity f32) {
	layout.shape.opacity = opacity
	for mut child in layout.children {
		propagate_opacity(mut child, opacity)
	}
}

fn apply_hero_recursive(mut layout Layout, progress f32, outgoing map[string]HeroSnapshot, incoming map[string]HeroSnapshot) {
	if layout.shape.hero && layout.shape.id != '' {
		id := layout.shape.id

		// Split animation: first half for morph, second half for text fade
		morph_progress := f32_min(1, progress * 2) // 0-0.5 -> 0-1
		fade_progress := f32_max(0, (progress - 0.5) * 2) // 0.5-1 -> 0-1

		if out := outgoing[id] {
			if _ := incoming[id] {
				// Matched hero: interpolate from outgoing to current (incoming) position
				layout.shape.x = lerp(out.x, layout.shape.x, morph_progress)
				layout.shape.y = lerp(out.y, layout.shape.y, morph_progress)
				layout.shape.width = lerp(out.width, layout.shape.width, morph_progress)
				layout.shape.height = lerp(out.height, layout.shape.height, morph_progress)
			}
			// Outgoing only (no match in incoming): element is leaving, don't render
		} else {
			// Incoming only (new element): fade in after morph completes
			propagate_opacity(mut layout, fade_progress)
		}
	}
	for mut child in layout.children {
		apply_hero_recursive(mut child, progress, outgoing, incoming)
	}
}
