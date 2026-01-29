module gui

import time

// Keyframe represents a single animation waypoint
pub struct Keyframe {
pub:
	at     f32 // position 0.0-1.0
	value  f32
	easing EasingFn = ease_linear // easing TO this keyframe
}

// KeyframeAnimation interpolates through multiple waypoints with per-segment easing.
//
// Unlike TweenAnimation which interpolates linearly between two values, KeyframeAnimation
// supports multiple waypoints (keyframes) with independent easing between each segment.
// This enables complex multi-phase animations like bounce effects, staged transitions,
// or animations that pause at intermediate values.
//
// # Keyframe Structure
//
// Each keyframe specifies:
// - `at`: Position in the animation timeline (0.0 = start, 1.0 = end)
// - `value`: The target value at this point
// - `easing`: Easing function used when interpolating TO this keyframe
//
// # Interpolation Algorithm
//
// At any point in time, the animation finds which two keyframes it's between, calculates
// the local progress within that segment, applies the destination keyframe's easing, then
// interpolates between the two values. For example, with keyframes at 0.0, 0.5, and 1.0:
// - Progress 0.25 → between keyframes 0 and 1, local progress 0.5
// - Progress 0.75 → between keyframes 1 and 2, local progress 0.5
//
// # Fields
//
// - `id`: Unique identifier (required). Used for animation replacement/lookup.
// - `duration`: Total animation duration (default 500ms).
// - `keyframes`: Array of Keyframe waypoints (required). Should include at least 2
//   keyframes, typically starting at `at: 0.0` and ending at `at: 1.0`.
// - `on_value`: Callback invoked each frame with interpolated value (required).
// - `on_done`: Optional callback when animation completes.
// - `repeat`: If true, animation loops indefinitely. `on_done` is never called.
//
// # Example: Bounce Effect
//
// ```
// mut bounce := gui.KeyframeAnimation{
//     id:       'bounce'
//     duration: 600 * time.millisecond
//     keyframes: [
//         gui.Keyframe{ at: 0.0, value: 0 },
//         gui.Keyframe{ at: 0.4, value: 100, easing: gui.ease_out_cubic },
//         gui.Keyframe{ at: 0.7, value: 85, easing: gui.ease_in_out_cubic },
//         gui.Keyframe{ at: 1.0, value: 100, easing: gui.ease_out_bounce },
//     ]
//     on_value: fn (v f32, mut w gui.Window) {
//         mut state := w.state[MyState]()
//         state.y_offset = v
//     }
// }
// w.animation_add(mut bounce)
// ```
//
// # Example: Pulsing Opacity
//
// ```
// mut pulse := gui.KeyframeAnimation{
//     id:       'pulse'
//     duration: 1000 * time.millisecond
//     repeat:   true
//     keyframes: [
//         gui.Keyframe{ at: 0.0, value: 1.0 },
//         gui.Keyframe{ at: 0.5, value: 0.3, easing: gui.ease_in_out_sine },
//         gui.Keyframe{ at: 1.0, value: 1.0, easing: gui.ease_in_out_sine },
//     ]
//     on_value: fn (v f32, mut w gui.Window) {
//         mut state := w.state[MyState]()
//         state.opacity = v
//     }
// }
// w.animation_add(mut pulse)
// ```
//
// # Best Practices
//
// - Always include keyframes at `at: 0.0` and `at: 1.0` to define full range
// - First keyframe's easing is ignored (nothing to ease from)
// - Keep keyframes sorted by `at` value (ascending)
// - Use TweenAnimation for simple A→B transitions; KeyframeAnimation for complex paths
// - For smooth loops with `repeat: true`, ensure first and last values match
pub struct KeyframeAnimation implements Animation {
pub:
	id        string @[required]
	duration  time.Duration = 500 * time.millisecond
	keyframes []Keyframe           @[required]
	on_value  fn (f32, mut Window) @[required]
	on_done   fn (mut Window) = unsafe { nil }
	repeat    bool
mut:
	delay   time.Duration
	start   time.Time
	stopped bool
}

fn update_keyframe(mut kf KeyframeAnimation, mut w Window, mut deferred []AnimationCallback) bool {
	if kf.stopped {
		return false
	}

	elapsed := time.since(kf.start)
	if elapsed < kf.delay {
		return false
	}

	anim_elapsed := elapsed - kf.delay
	if anim_elapsed >= kf.duration {
		if kf.keyframes.len > 0 {
			kf.on_value(kf.keyframes.last().value, mut w)
		}
		if kf.repeat {
			kf.start = time.now()
			return true
		}
		if kf.on_done != unsafe { nil } {
			deferred << kf.on_done
		}
		kf.stopped = true
		return true
	}

	progress := f32(anim_elapsed) / f32(kf.duration)
	value := interpolate_keyframes(kf.keyframes, progress)
	kf.on_value(value, mut w)
	return true
}

fn interpolate_keyframes(keyframes []Keyframe, progress f32) f32 {
	if keyframes.len < 2 {
		return if keyframes.len == 1 { keyframes[0].value } else { 0 }
	}

	// Binary search to find segment
	mut lo := 0
	mut hi := keyframes.len - 1
	for lo < hi {
		mid := (lo + hi) / 2
		if keyframes[mid].at < progress {
			lo = mid + 1
		} else {
			hi = mid
		}
	}

	// lo is now the first keyframe with at >= progress (or len-1 if past all)
	if lo == 0 {
		return keyframes[0].value
	}

	prev := keyframes[lo - 1]
	curr := keyframes[lo]
	segment_len := curr.at - prev.at
	if segment_len <= 0 {
		return curr.value
	}
	local := (progress - prev.at) / segment_len
	return lerp(prev.value, curr.value, curr.easing(local))
}
