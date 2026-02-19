module gui

import time

const animation_cycle = 16 * time.millisecond
const animation_delay = 500 * time.millisecond
const blink_cursor_animation_id = '___blinky_cursor_animation___'
const blink_cursor_animation_delay = 600 * time.millisecond

enum AnimationRefreshKind as u8 {
	none
	render_only
	layout
}

type AnimationCallback = fn (mut Window)

interface Animation {
	id string
	refresh_kind() AnimationRefreshKind
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
pub mut:
	delay  time.Duration = animation_delay
	repeat bool
mut:
	start   time.Time
	stopped bool
}

fn (_ Animate) refresh_kind() AnimationRefreshKind {
	return .layout
}

struct BlinkCursorAnimation implements Animation {
pub:
	id string = blink_cursor_animation_id
mut:
	delay   time.Duration = blink_cursor_animation_delay
	start   time.Time
	stopped bool
}

fn (_ BlinkCursorAnimation) refresh_kind() AnimationRefreshKind {
	return .render_only
}

// animation_add registers a new animation to the window's animation queue.
// If an animation with the same id already exists, it will be replaced.
// The animation's start time is set to the current time and will be processed
// in the animation loop.
pub fn (mut window Window) animation_add(mut animation Animation) {
	if window.try_lock() {
		defer { window.unlock() }
	}
	animation.start = time.now()
	window.animations[animation.id] = animation
}

// has_animation returns true if an animation with the given id is
// currently active. Safe to call during view generation (no lock).
pub fn (window &Window) has_animation(id string) bool {
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
		mut refresh_kind := AnimationRefreshKind.none
		mut deferred := []AnimationCallback{}
		mut stopped_ids := []string{}
		//--------------------------------------------
		window.lock()
		for _, mut animation in window.animations {
			match mut animation {
				Animate {
					if update_animate(mut animation, mut window, mut deferred) {
						refresh_kind = max_animation_refresh_kind(refresh_kind, animation.refresh_kind())
					}
				}
				BlinkCursorAnimation {
					if update_blink_cursor(mut animation, mut window) {
						refresh_kind = max_animation_refresh_kind(refresh_kind, animation.refresh_kind())
					}
				}
				TweenAnimation {
					if update_tween(mut animation, mut window, mut deferred) {
						refresh_kind = max_animation_refresh_kind(refresh_kind, animation.refresh_kind())
					}
				}
				SpringAnimation {
					if update_spring(mut animation, mut window, dt, mut deferred) {
						refresh_kind = max_animation_refresh_kind(refresh_kind, animation.refresh_kind())
					}
				}
				LayoutTransition {
					if update_layout_transition(mut animation, mut window, mut deferred) {
						refresh_kind = max_animation_refresh_kind(refresh_kind, animation.refresh_kind())
					}
				}
				HeroTransition {
					if update_hero_transition(mut animation, mut window, mut deferred) {
						refresh_kind = max_animation_refresh_kind(refresh_kind, animation.refresh_kind())
					}
				}
				KeyframeAnimation {
					if update_keyframe(mut animation, mut window, mut deferred) {
						refresh_kind = max_animation_refresh_kind(refresh_kind, animation.refresh_kind())
					}
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
		// Queue deferred callbacks to be executed on the main thread
		for cb in deferred {
			window.queue_command(cb)
		}
		match refresh_kind {
			.render_only {
				window.request_render_only()
			}
			.layout {
				window.update_window()
			}
			.none {}
		}
	}
}

fn max_animation_refresh_kind(current AnimationRefreshKind, incoming AnimationRefreshKind) AnimationRefreshKind {
	if current == .layout || incoming == .layout {
		return .layout
	}
	if current == .render_only || incoming == .render_only {
		return .render_only
	}
	return .none
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

fn update_blink_cursor(mut b BlinkCursorAnimation, mut w Window) bool {
	if b.stopped {
		return false
	}
	if time.since(b.start) > b.delay {
		if w.view_state.cursor_on_sticky {
			w.view_state.input_cursor_on = true
			w.view_state.cursor_on_sticky = false
		} else {
			w.view_state.input_cursor_on = !w.view_state.input_cursor_on
		}
		b.start = time.now()
		return true
	}
	return false
}
