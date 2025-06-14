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

pub struct AnimationDelay implements Animation {
pub:
	id       string @[required]
	delay    time.Duration = animation_delay
	callback fn (mut Window) @[required]
mut:
	start   time.Time
	stopped bool
}

pub fn (mut w Window) animation_add(mut animation Animation) {
	w.lock()
	w.animations = w.animations.filter(it.id != animation.id)
	animation.start = time.now()
	w.animations << animation
	w.unlock()
}

fn (mut w Window) animaton_loop() {
	for {
		time.sleep(animation_cycle)
		w.lock()

		mut refresh := false
		for mut animation in w.animations {
			match mut animation {
				AnimationDelay { refresh = update_animation_delay(mut animation, mut w) }
				else {}
			}
		}

		// remove any spent animations
		w.animations = w.animations.filter(!it.stopped)
		w.unlock()
		if refresh {
			w.update_window()
		}
	}
}

fn update_animation_delay(mut ad AnimationDelay, mut w Window) bool {
	if time.since(ad.start) > ad.delay {
		ad.stopped = true
		ad.callback(mut w)
		return true
	}
	return false
}
