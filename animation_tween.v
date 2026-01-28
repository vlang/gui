module gui

import time

// TweenAnimation interpolates from one value to another over a duration
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
