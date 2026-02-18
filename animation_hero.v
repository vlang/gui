module gui

import time

// HeroSnapshot captures element state for hero transitions
struct HeroSnapshot {
	x      f32
	y      f32
	width  f32
	height f32
}

// HeroTransitionCfg configures hero transition
pub struct HeroTransitionCfg {
pub:
	duration time.Duration
	easing   ?EasingFn
}

// HeroTransition animates elements between views.
// Only one HeroTransition can be active at a time (uses fixed internal ID).
pub struct HeroTransition implements Animation {
pub:
	id       string          = '__hero_transition__' // internal: only one active at a time
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

fn (_ HeroTransition) refresh_kind() AnimationRefreshKind {
	return .layout
}

// transition_to_view switches to a new view with animated hero element transitions.
//
// Hero transitions create smooth visual continuity when navigating between views by
// animating shared elements (heroes) from their old positions to their new positions.
// This is commonly used for list-to-detail transitions where a thumbnail morphs into
// a full image, or navigation transitions where a title moves to a new location.
//
// # How It Works
//
// 1. Captures positions of all hero elements in the current view (outgoing)
// 2. Switches to the new view generator
// 3. Generates the new layout to capture hero positions (incoming)
// 4. Creates a HeroTransition animation that interpolates between snapshots
//
// # Hero Element Matching
//
// Elements are matched by their `id` field. An element in the old view with id="card_1"
// will animate to the element in the new view with id="card_1". Elements must also have
// `hero: true` set to participate in the transition.
//
// # Animation Phases
//
// The transition runs in two phases over the configured duration:
// - First half (0-50%): Matched heroes morph position/size from old to new
// - Second half (50-100%): New-only elements fade in
//
// Elements that exist only in the outgoing view are not rendered during transition.
//
// # Parameters
//
// - `gen`: View generator function for the new view. Called twice: once to capture
//   incoming hero positions, then used as the active view generator.
// - `cfg`: Optional configuration for duration (default 300ms) and easing
//   (default ease_out_cubic).
//
// # Example
//
// ```
// // Mark elements as heroes with matching IDs
// fn list_view(mut w Window) View {
//     return row(
//         .{},
//         [image(.{ id: 'product_img', hero: true, src: 'thumb.png' })]
//     )
// }
//
// fn detail_view(mut w Window) View {
//     return column(
//         .{},
//         [image(.{ id: 'product_img', hero: true, src: 'full.png' })]
//     )
// }
//
// // Trigger transition on click
// fn on_click(mut w Window) {
//     w.transition_to_view(detail_view, .{})
// }
// ```
//
// # Requirements
//
// - Hero elements must have both `id` and `hero: true` set
// - IDs must match between views for elements to animate together
// - Only one HeroTransition can be active at a time; starting a new one replaces any
//   in-progress transition
pub fn (mut w Window) transition_to_view(gen fn (mut Window) View, cfg HeroTransitionCfg) {
	// Capture outgoing hero elements
	outgoing := capture_hero_snapshots(w.layout)

	// Switch to new view
	w.lock()
	w.clear_view_state()
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

	dur := if cfg.duration != 0 { cfg.duration } else { 300 * time.millisecond }
	eas := cfg.easing or { ease_out_cubic }
	mut transition := &HeroTransition{
		duration: dur
		easing:   eas
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
			x:      layout.shape.x
			y:      layout.shape.y
			width:  layout.shape.width
			height: layout.shape.height
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
	animation := w.animations['__hero_transition__'] or { return }
	if animation is HeroTransition {
		if animation.stopped {
			return
		}
		apply_hero_recursive(mut layout, animation.progress, animation.outgoing, animation.incoming)
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
