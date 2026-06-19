module gui

import builtin.closure as closure_api

const layout_callback_retain_frames = 1

struct LayoutCallbackLifetime {
mut:
	lifetime        closure_api.Lifetime
	initialized     bool
	disposed        bool
	dispose_pending bool
	reclaim_pins    int
}

fn new_layout_callback_lifetime() LayoutCallbackLifetime {
	return LayoutCallbackLifetime{
		lifetime:    closure_api.new_lifetime()
		initialized: true
	}
}

fn (mut window Window) ensure_layout_callback_lifetime() {
	if window.layout_callback_lifetime.initialized || window.layout_callback_lifetime.disposed {
		return
	}
	window.layout_callback_lifetime.lifetime = closure_api.new_lifetime()
	window.layout_callback_lifetime.initialized = true
}

fn (mut window Window) layout_callback_frame(work fn ()) ! {
	if window.layout_callback_lifetime.disposed {
		return error('layout callback lifetime has been disposed')
	}
	window.ensure_layout_callback_lifetime()
	window.layout_callback_lifetime.lifetime.frame(work)!
}

fn (mut window Window) reclaim_old_layout_callbacks() {
	if window.layout_callback_lifetime.disposed {
		return
	}
	if window.layout_callback_lifetime.reclaim_pins > 0 {
		return
	}
	window.ensure_layout_callback_lifetime()
	window.layout_callback_lifetime.lifetime.reclaim(layout_callback_retain_frames) or {
		panic(err)
	}
}

fn (mut window Window) pin_layout_callback_reclaim() ! {
	if window.layout_callback_lifetime.disposed || window.layout_callback_lifetime.dispose_pending {
		return error('layout callback lifetime has been disposed')
	}
	window.ensure_layout_callback_lifetime()
	window.layout_callback_lifetime.reclaim_pins++
}

fn (mut window Window) release_layout_callback_reclaim_pin() {
	if window.layout_callback_lifetime.disposed {
		return
	}
	if window.layout_callback_lifetime.reclaim_pins > 0 {
		window.layout_callback_lifetime.reclaim_pins--
	}
	if window.layout_callback_lifetime.reclaim_pins == 0
		&& window.layout_callback_lifetime.dispose_pending {
		window.dispose_layout_callbacks()
	}
}

fn (mut window Window) suspend_layout_callback_tracking(work fn ()) ! {
	if window.layout_callback_lifetime.disposed {
		return error('layout callback lifetime has been disposed')
	}
	window.ensure_layout_callback_lifetime()
	window.layout_callback_lifetime.lifetime.suspend(work)!
}

fn (mut window Window) dispose_layout_callbacks() {
	if window.layout_callback_lifetime.disposed {
		return
	}
	if window.layout_callback_lifetime.reclaim_pins > 0 {
		window.layout_callback_lifetime.dispose_pending = true
		return
	}
	if !window.layout_callback_lifetime.initialized {
		window.layout_callback_lifetime.disposed = true
		window.layout_callback_lifetime.dispose_pending = false
		return
	}
	window.layout_callback_lifetime.lifetime.dispose() or { panic(err) }
	window.layout_callback_lifetime.disposed = true
	window.layout_callback_lifetime.dispose_pending = false
}
