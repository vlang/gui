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
	repeat bool
pub:
	id       string          @[required]
	callback fn (mut Window) @[required]
	delay    time.Duration = animation_delay
mut:
	start   time.Time
	stopped bool
}

pub fn (mut window Window) animation_add(mut animation Animation) {
	window.animations = window.animations.filter(it.id != animation.id)
	unsafe { window.animations.flags.set(.noslices) }
	defer { unsafe { window.animations.flags.clear(.noslices) } }
	animation.start = time.now()
	window.animations << animation
}

fn (mut window Window) animation_loop() {
	for {
		time.sleep(animation_cycle)
		window.lock()

		mut refresh := false
		for mut animation in window.animations {
			match mut animation {
				Animate { refresh = refresh || update_animate(mut animation, mut window) }
				else {}
			}
		}

		// remove any stopped animations
		window.animations = window.animations.filter(!it.stopped)
		window.unlock()
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
