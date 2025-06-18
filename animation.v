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

pub fn (mut w Window) animation_add(mut animation Animation) {
	w.animations = w.animations.filter(it.id != animation.id)
	animation.start = time.now()
	w.animations << animation
}

fn (mut w Window) animaton_loop() {
	for {
		time.sleep(animation_cycle)
		w.lock()

		mut refresh := false
		for mut animation in w.animations {
			match mut animation {
				Animate { refresh = refresh || update_animate(mut animation, mut w) }
				else {}
			}
		}

		// remove any stopped animations
		w.animations = w.animations.filter(!it.stopped)
		w.unlock()
		if refresh {
			w.update_window()
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
