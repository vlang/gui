module gui

import time

const animation_cycle = 16 * time.millisecond
const animation_delay = 500 * time.millisecond

type AnimationCallback = fn (mut Window)

interface Animation {
	id string
mut:
	delay   time.Duration
	start   time.Time
	stopped bool
}

// Animate waits the specified delay duration and then executes the callback.
pub struct Animate implements Animation {
pub:
	id       string                       @[required]
	callback fn (mut Animate, mut Window) @[required]
mut:
	delay   time.Duration = animation_delay
	start   time.Time
	stopped bool
	repeat  bool
}

// animation_add registers a new animation to the window's animation queue.
// If an animation with the same id already exists, it will be replaced.
// The animation's start time is set to the current time and will be processed
// in the animation loop.
pub fn (mut window Window) animation_add(mut animation Animation) {
	window.lock()
	defer { window.unlock() }
	animation.start = time.now()
	window.animations[animation.id] = animation
}

// has_animation returns true if an animation with the given id is currently active.
pub fn (mut window Window) has_animation(id string) bool {
	window.lock()
	defer { window.unlock() }
	return id in window.animations
}

// remove_animation stops and removes an animation by id.
pub fn (mut window Window) remove_animation(id string) {
	window.lock()
	defer { window.unlock() }
	window.animations.delete(id)
}

fn (mut window Window) animation_loop() {
	// dt in seconds for spring physics
	dt := f32(animation_cycle) / f32(time.second)

	for {
		time.sleep(animation_cycle)
		mut refresh := false
		mut deferred := []AnimationCallback{}
		mut stopped_ids := []string{}
		//--------------------------------------------
		window.lock()
		for _, mut animation in window.animations {
			match mut animation {
				Animate {
					refresh = update_animate(mut animation, mut window, mut deferred) || refresh
				}
				TweenAnimation {
					refresh = update_tween(mut animation, mut window, mut deferred) || refresh
				}
				SpringAnimation {
					refresh = update_spring(mut animation, mut window, dt, mut deferred) || refresh
				}
				LayoutTransition {
					refresh = update_layout_transition(mut animation, mut window, mut deferred)
						|| refresh
				}
				HeroTransition {
					refresh = update_hero_transition(mut animation, mut window, mut deferred)
						|| refresh
				}
				KeyframeAnimation {
					refresh = update_keyframe(mut animation, mut window, mut deferred) || refresh
				}
				else {}
			}
			if animation.stopped {
				stopped_ids << animation.id
			}
		}
		for id in stopped_ids {
			window.animations.delete(id)
		}
		window.unlock()
		//--------------------------------------------
		// Call deferred callbacks outside lock to avoid deadlock
		for cb in deferred {
			cb(mut window)
		}
		if refresh {
			window.update_window()
		}
	}
}

fn update_animate(mut an Animate, mut w Window, mut deferred []AnimationCallback) bool {
	if !an.stopped {
		if time.since(an.start) > an.delay {
			// Capture callback to call after lock release
			callback := an.callback
			deferred << fn [callback, mut an] (mut w Window) {
				callback(mut an, mut w)
			}
			match an.repeat {
				true { an.start = time.now() }
				else { an.stopped = true }
			}
			return true
		}
	}
	return false
}
