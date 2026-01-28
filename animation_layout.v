module gui

import time

// LayoutSnapshot captures element position/size
struct LayoutSnapshot {
	x      f32
	y      f32
	width  f32
	height f32
}

// LayoutTransitionCfg configures layout animation
pub struct LayoutTransitionCfg {
pub:
	duration time.Duration = 200 * time.millisecond
	easing   EasingFn      = ease_out_cubic
}

// LayoutTransition animates layout changes (resize, reorder)
pub struct LayoutTransition implements Animation {
pub:
	id       string          = '__layout_transition__'
	duration time.Duration   = 200 * time.millisecond
	easing   EasingFn        = ease_out_cubic
	on_done  fn (mut Window) = unsafe { nil }
mut:
	delay     time.Duration
	start     time.Time
	stopped   bool
	snapshots map[string]LayoutSnapshot
	progress  f32
}

// animate_layout triggers layout transition animation
// Call before making layout changes - captures current state
pub fn (mut w Window) animate_layout(cfg LayoutTransitionCfg) {
	mut transition := &LayoutTransition{
		duration:  cfg.duration
		easing:    cfg.easing
		snapshots: capture_layout_snapshots(w.layout)
	}
	w.animation_add(mut transition)
}

// capture_layout_snapshots recursively captures all element positions
fn capture_layout_snapshots(layout Layout) map[string]LayoutSnapshot {
	mut snapshots := map[string]LayoutSnapshot{}
	capture_recursive(layout, mut snapshots)
	return snapshots
}

fn capture_recursive(layout Layout, mut snapshots map[string]LayoutSnapshot) {
	if layout.shape.id != '' {
		snapshots[layout.shape.id] = LayoutSnapshot{
			x:      layout.shape.x
			y:      layout.shape.y
			width:  layout.shape.width
			height: layout.shape.height
		}
	}
	for child in layout.children {
		capture_recursive(child, mut snapshots)
	}
}

fn update_layout_transition(mut lt LayoutTransition, mut w Window, mut deferred []AnimationCallback) bool {
	if lt.stopped {
		return false
	}

	elapsed := time.since(lt.start)
	if elapsed < lt.delay {
		return false
	}

	anim_elapsed := elapsed - lt.delay
	if anim_elapsed >= lt.duration {
		lt.progress = 1.0
		lt.stopped = true
		if lt.on_done != unsafe { nil } {
			deferred << lt.on_done
		}
		return true
	}

	progress := f32(anim_elapsed) / f32(lt.duration)
	lt.progress = lt.easing(progress)
	return true
}

// get_layout_transition returns active layout transition if any
fn (w &Window) get_layout_transition() ?&LayoutTransition {
	for animation in w.animations {
		if animation is LayoutTransition {
			return animation
		}
	}
	return none
}

// apply_layout_transition interpolates positions during amend phase
fn apply_layout_transition(mut layout Layout, w &Window) {
	transition := w.get_layout_transition() or { return }
	if transition.stopped {
		return
	}
	apply_transition_recursive(mut layout, transition)
}

fn apply_transition_recursive(mut layout Layout, transition &LayoutTransition) {
	if layout.shape.id != '' {
		if old := transition.snapshots[layout.shape.id] {
			t := transition.progress
			// Interpolate from old to new position
			layout.shape.x = lerp(old.x, layout.shape.x, t)
			layout.shape.y = lerp(old.y, layout.shape.y, t)
			layout.shape.width = lerp(old.width, layout.shape.width, t)
			layout.shape.height = lerp(old.height, layout.shape.height, t)
		}
	}
	for mut child in layout.children {
		apply_transition_recursive(mut child, transition)
	}
}
