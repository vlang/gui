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
	duration time.Duration
	easing   ?EasingFn
}

// LayoutTransition animates layout changes such as resize, reorder, add, or remove.
//
// This implements a FLIP-style animation (First, Last, Invert, Play): capture element
// positions before a layout change, let the layout recalculate, then animate elements
// from their old positions to their new positions. The framework handles the inversion
// and interpolation automatically.
//
// # How It Works
//
// 1. Call `w.animate_layout()` BEFORE making layout changes - this captures current
//    positions of all elements with IDs into snapshots
// 2. Make your layout changes (add/remove items, resize, reorder, etc.)
// 3. On next frame, the layout system calculates new positions
// 4. During render, LayoutTransition interpolates each element from its old snapshot
//    position toward its new calculated position based on progress
//
// # Element Matching
//
// Elements are matched between old and new layouts by their `id` field. Only elements
// with non-empty IDs participate in the transition. Elements without IDs, or elements
// that exist only in the new layout (no snapshot), appear instantly at their new
// position.
//
// # Fields
//
// - `id`: Fixed internal identifier. Cannot be changed; only one LayoutTransition can
//   be active at a time. Starting a new one replaces any in-progress transition.
// - `duration`: Animation duration (default 200ms). Short duration recommended for
//   responsive feel.
// - `easing`: Easing function (default ease_out_cubic). Applied to overall progress.
// - `on_done`: Optional callback when animation completes.
// - `snapshots`: Internal map of element ID → captured position/size before change.
// - `progress`: Current animation progress (0.0 to 1.0), easing-adjusted.
//
// # Interpolated Properties
//
// For each matched element, the following properties are interpolated:
// - `x`, `y`: Position
// - `width`, `height`: Size
//
// # Usage Pattern
//
// Always call `animate_layout()` immediately before the state change that triggers
// layout recalculation:
//
// ```
// fn on_reorder(mut w gui.Window) {
//     w.animate_layout(.{})  // capture current positions
//     mut state := w.state[MyState]()
//     state.items.sort()     // trigger layout change
// }
//
// fn on_remove(mut w gui.Window, index int) {
//     w.animate_layout(.{ duration: 150 * time.millisecond })
//     mut state := w.state[MyState]()
//     state.items.delete(index)
// }
// ```
//
// # Example: Animated List
//
// ```
// fn list_view(mut w gui.Window) gui.View {
//     state := w.state[MyState]()
//     return gui.column(.{}, state.items.map(|item|
//         gui.container(
//             .{ id: 'item_${item.id}' },  // ID required for animation
//             [gui.text(.{}, item.name)]
//         )
//     ))
// }
//
// fn shuffle_items(mut w gui.Window) {
//     w.animate_layout(.{})
//     mut state := w.state[MyState]()
//     state.items.shuffle()
// }
// ```
//
// # Limitations
//
// - Only one LayoutTransition can run at a time (fixed internal ID)
// - Elements must have `id` set to participate in animation
// - New elements (no snapshot) appear instantly; removed elements disappear instantly
// - Does not animate opacity, color, or other visual properties
//
// # Comparison with HeroTransition
//
// - LayoutTransition: Same view, elements move within current layout
// - HeroTransition: Different views, elements animate across view boundary
//
// Use LayoutTransition for in-place changes (sort, filter, resize). Use HeroTransition
// for navigation between different views.
pub struct LayoutTransition implements Animation {
pub:
	id       string          = '__layout_transition__' // internal: only one active at a time
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

fn (_ LayoutTransition) refresh_kind() AnimationRefreshKind {
	return .layout
}

// animate_layout triggers layout transition animation
// Call before making layout changes - captures current state
pub fn (mut w Window) animate_layout(cfg LayoutTransitionCfg) {
	dur := if cfg.duration != 0 { cfg.duration } else { 200 * time.millisecond }
	eas := cfg.easing or { ease_out_cubic }
	mut transition := &LayoutTransition{
		duration:  dur
		easing:    eas
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
	animation := w.animations['__layout_transition__'] or { return none }
	if animation is LayoutTransition {
		return animation
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
