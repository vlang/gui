module gui

import time

const animation_cycle = 16 * time.millisecond
const animation_delay = 500 * time.millisecond

interface Animation {
	id string
mut:
	start   time.Time
	stopped bool
}

// Animate waits the specified delay duration and then executes the callback.
pub struct Animate implements Animation {
pub:
	id       string          @[required]
	callback fn (mut Window) @[required]
	delay    time.Duration = animation_delay
mut:
	start   time.Time
	repeat  bool
	stopped bool
}

// animation_add registers a new animation to the window's animation queue.
// If an animation with the same id already exists, it will be replaced.
// The animation's start time is set to the current time and will be processed
// in the animation loop.
pub fn (mut window Window) animation_add(mut animation Animation) {
	window.lock()
	defer { window.unlock() }
	window.animations = window.animations.filter(it.id != animation.id)
	window.animations << animation
	animation.start = time.now()
}

pub fn (mut window Window) has_animation(id string) bool {
	window.lock()
	defer { window.unlock() }
	return window.animations.any(it.id == id)
}

pub fn (mut window Window) remove_animation(id string) {
	window.lock()
	defer { window.unlock() }
	window.animations = window.animations.filter(it.id != id)
}

fn (mut window Window) animation_loop() {
	for {
		time.sleep(animation_cycle)
		mut refresh := false
		//--------------------------------------------
		window.lock()
		for mut animation in window.animations {
			match mut animation {
				Animate { refresh = update_animate(mut animation, mut window) || refresh }
				else {}
			}
		}
		window.animations = window.animations.filter(!it.stopped)
		window.unlock()
		//--------------------------------------------
		if refresh {
			window.update_window()
		}
	}
}

fn update_animate(mut an Animate, mut w Window) bool {
	if !an.stopped {
		if time.since(an.start) > an.delay {
			an.callback(mut w)
			match an.repeat {
				true { an.start = time.now() }
				else { an.stopped = true }
			}
			return true
		}
	}
	return false
}
