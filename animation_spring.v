module gui

import time

// SpringConfig controls spring physics behavior
pub struct SpringConfig {
pub:
	stiffness f32 = 100.0 // higher = snappier response
	damping   f32 = 10.0  // higher = less oscillation
	mass      f32 = 1.0   // higher = more inertia
	threshold f32 = 0.01  // settling threshold
}

// spring_default is a balanced spring for general-purpose animations.
pub const spring_default = SpringConfig{
	stiffness: 100
	damping:   10
}

// spring_gentle is a slow, smooth spring with minimal overshoot.
pub const spring_gentle = SpringConfig{
	stiffness: 50
	damping:   8
}

// spring_bouncy is a lively spring with noticeable oscillation.
pub const spring_bouncy = SpringConfig{
	stiffness: 300
	damping:   15
}

// spring_stiff is a fast, snappy spring with minimal bounce.
pub const spring_stiff = SpringConfig{
	stiffness: 500
	damping:   30
}

// SpringState tracks current spring physics
struct SpringState {
mut:
	position f32
	velocity f32
	target   f32
	at_rest  bool
}

// SpringAnimation uses spring physics for natural motion
pub struct SpringAnimation implements Animation {
pub:
	id       string @[required]
	config   SpringConfig = spring_default
	on_value fn (f32, mut Window) @[required]
	on_done  fn (mut Window) = unsafe { nil }
mut:
	delay   time.Duration
	start   time.Time
	stopped bool
	state   SpringState
}

// spring_to sets spring target, starting from current position or `from` value
pub fn (mut s SpringAnimation) spring_to(from f32, to f32) {
	s.state.position = from
	s.state.velocity = 0
	s.state.target = to
	s.state.at_rest = false
	s.stopped = false
}

// retarget changes target while preserving current position/velocity
pub fn (mut s SpringAnimation) retarget(to f32) {
	s.state.target = to
	s.state.at_rest = false
	s.stopped = false
}

fn update_spring(mut sp SpringAnimation, mut w Window, dt f32, mut deferred []AnimationCallback) bool {
	if sp.stopped || sp.state.at_rest {
		return false
	}

	elapsed := time.since(sp.start)
	if elapsed < sp.delay {
		return false
	}

	// Spring physics: F = -kx - cv
	// k = stiffness, c = damping, x = displacement, v = velocity
	cfg := sp.config
	displacement := sp.state.position - sp.state.target
	spring_force := -cfg.stiffness * displacement
	damping_force := -cfg.damping * sp.state.velocity
	acceleration := (spring_force + damping_force) / cfg.mass

	// Euler integration
	sp.state.velocity += acceleration * dt
	sp.state.position += sp.state.velocity * dt

	// Check if at rest
	if f32_abs(sp.state.velocity) < cfg.threshold && f32_abs(displacement) < cfg.threshold {
		sp.state.position = sp.state.target
		sp.state.velocity = 0
		sp.state.at_rest = true
		sp.on_value(sp.state.target, mut w)
		if sp.on_done != unsafe { nil } {
			deferred << sp.on_done
		}
		sp.stopped = true
		return true
	}

	sp.on_value(sp.state.position, mut w)
	return true
}
