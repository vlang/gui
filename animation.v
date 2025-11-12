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

pub fn (mut window Window) animation_add(mut animation Animation) {
	window.lock()
	window.animations = window.animations.filter(it.id != animation.id)
	window.animations << animation
	animation.start = time.now()
	window.unlock()
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
