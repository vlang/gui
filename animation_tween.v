module gui

import time

// TweenAnimation interpolates a value from A to B over a fixed duration with easing.
//
// This is the simplest and most common animation type. Given a start value, end value,
// and duration, it calculates intermediate values each frame using linear interpolation
// modified by an easing function. The animation progresses predictably and completes
// at exactly the specified duration.
//
// # How It Works
//
// Each frame:
// 1. Calculate raw progress: elapsed_time / duration (0.0 to 1.0)
// 2. Apply easing function to progress (e.g., ease_out_cubic for deceleration)
// 3. Interpolate: value = from + (to - from) * eased_progress
// 4. Call on_value with the interpolated value
//
// # Fields
//
// - `id`: Unique identifier (required). If an animation with the same ID already exists,
//   the new animation replaces it. Use descriptive IDs like 'sidebar_width' or
//   'fade_opacity'.
// - `duration`: How long the animation runs (default 300ms). Animation completes at
//   exactly this time regardless of frame rate.
// - `easing`: Function that shapes the animation curve (default ease_out_cubic). See
//   animation_easing.v for available functions.
// - `from`: Starting value. Animation begins here on first frame after delay.
// - `to`: Target value. Animation ends exactly at this value.
// - `on_value`: Callback invoked each frame with the current interpolated value
//   (required). Use this to update your state.
// - `on_done`: Optional callback invoked once when animation completes. Useful for
//   chaining animations or updating boolean flags.
// - `delay`: Time to wait before animation starts. The animation is added immediately
//   but on_value isn't called until delay elapses.
//
// # Easing Functions
//
// The easing function transforms linear progress into curved motion:
// - `ease_linear`: Constant speed, no acceleration (robotic feel)
// - `ease_in_*`: Start slow, accelerate (ease_in_quad, ease_in_cubic, ease_in_quart)
// - `ease_out_*`: Start fast, decelerate (ease_out_quad, ease_out_cubic, ease_out_quart)
// - `ease_in_out_*`: Slow start and end, fast middle (ease_in_out_cubic, etc.)
// - `ease_out_bounce`: Bouncy settling effect
// - `ease_out_elastic`: Springy overshoot effect
// - `ease_out_back`: Slight overshoot then settle
//
// ease_out_cubic is the default because it provides natural-feeling deceleration that
// works well for most UI animations.
//
// # Example: Fade In
//
// ```
// mut fade := gui.TweenAnimation{
//     id:       'panel_fade'
//     duration: 200 * time.millisecond
//     from:     0.0
//     to:       1.0
//     easing:   gui.ease_out_quad
//     on_value: fn (v f32, mut w gui.Window) {
//         mut state := w.state[MyState]()
//         state.panel_opacity = v
//     }
// }
// w.animation_add(mut fade)
// ```
//
// # Example: Slide with Delay
//
// ```
// mut slide := gui.TweenAnimation{
//     id:       'menu_slide'
//     duration: 300 * time.millisecond
//     delay:    100 * time.millisecond  // wait before starting
//     from:     -200
//     to:       0
//     easing:   gui.ease_out_back  // slight overshoot
//     on_value: fn (v f32, mut w gui.Window) {
//         mut state := w.state[MyState]()
//         state.menu_x = v
//     }
//     on_done: fn (mut w gui.Window) {
//         mut state := w.state[MyState]()
//         state.menu_fully_open = true
//     }
// }
// w.animation_add(mut slide)
// ```
//
// # Example: Chained Animations
//
// ```
// fn start_sequence(mut w gui.Window) {
//     mut first := gui.TweenAnimation{
//         id:       'step1'
//         duration: 200 * time.millisecond
//         from:     0
//         to:       100
//         on_value: fn (v f32, mut w gui.Window) { ... }
//         on_done:  fn (mut w gui.Window) {
//             // Start second animation when first completes
//             mut second := gui.TweenAnimation{
//                 id:       'step2'
//                 duration: 200 * time.millisecond
//                 from:     100
//                 to:       200
//                 on_value: fn (v f32, mut w gui.Window) { ... }
//             }
//             w.animation_add(mut second)
//         }
//     }
//     w.animation_add(mut first)
// }
// ```
//
// # When to Use TweenAnimation
//
// Best for:
// - Simple A→B transitions (opacity, position, size, rotation)
// - Animations requiring precise timing
// - UI feedback (button press, hover effects)
// - Synchronized animations (multiple tweens with same duration)
//
// Consider alternatives:
// - KeyframeAnimation: Multiple waypoints or complex paths
// - SpringAnimation: Physics-based motion, interruptible animations
// - LayoutTransition: Animating element reordering/resizing
//
// # Animation Replacement
//
// If you add a TweenAnimation with an ID that already exists, the new animation
// replaces the old one. This is useful for retriggering:
//
// ```
// fn on_hover(mut w gui.Window) {
//     // Each hover restarts the animation from current state
//     mut tween := gui.TweenAnimation{
//         id:       'hover_glow'  // same ID = replacement
//         duration: 150 * time.millisecond
//         from:     0
//         to:       1
//         on_value: fn (v f32, mut w gui.Window) { ... }
//     }
//     w.animation_add(mut tween)
// }
// ```
pub struct TweenAnimation implements Animation {
pub:
	id       string @[required]
	duration time.Duration = 300 * time.millisecond
	easing   EasingFn      = ease_out_cubic
	from     f32
	to       f32
	on_value fn (f32, mut Window) @[required]
	on_done  fn (mut Window) = unsafe { nil }
mut:
	delay   time.Duration
	start   time.Time
	stopped bool
}

fn update_tween(mut tw TweenAnimation, mut w Window, mut deferred []AnimationCallback) bool {
	if tw.stopped {
		return false
	}

	elapsed := time.since(tw.start)
	if elapsed < tw.delay {
		return false
	}

	anim_elapsed := elapsed - tw.delay
	if anim_elapsed >= tw.duration {
		tw.on_value(tw.to, mut w)
		if tw.on_done != unsafe { nil } {
			deferred << tw.on_done
		}
		tw.stopped = true
		return true
	}

	// Calculate progress 0.0 to 1.0
	progress := f32(anim_elapsed) / f32(tw.duration)
	eased := tw.easing(progress)
	value := lerp(tw.from, tw.to, eased)
	tw.on_value(value, mut w)
	return true
}
