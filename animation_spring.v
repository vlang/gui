module gui

import time

// SpringCfg controls spring physics behavior
pub struct SpringCfg {
pub:
	stiffness f32 = 100.0 // higher = snappier response
	damping   f32 = 10.0  // higher = less oscillation
	mass      f32 = 1.0   // higher = more inertia
	threshold f32 = 0.01  // settling threshold
}

// spring_default is a balanced spring for general-purpose animations.
pub const spring_default = SpringCfg{
	stiffness: 100
	damping:   10
}

// spring_gentle is a slow, smooth spring with minimal overshoot.
pub const spring_gentle = SpringCfg{
	stiffness: 50
	damping:   8
}

// spring_bouncy is a lively spring with noticeable oscillation.
pub const spring_bouncy = SpringCfg{
	stiffness: 300
	damping:   15
}

// spring_stiff is a fast, snappy spring with minimal bounce.
pub const spring_stiff = SpringCfg{
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

// SpringAnimation uses spring physics simulation for natural, organic motion.
//
// Unlike duration-based animations (Tween, Keyframe), spring animations have no fixed
// duration. They simulate a damped harmonic oscillator: the value accelerates toward
// the target, potentially overshoots, oscillates, and eventually settles. This creates
// motion that feels physically realistic and responds naturally to interruption.
//
// # Physics Model
//
// The spring follows Hooke's law with damping: F = -kx - cv
// - k (stiffness): Spring constant. Higher = stronger pull toward target.
// - c (damping): Friction coefficient. Higher = less oscillation, faster settling.
// - x (displacement): Distance from target position.
// - v (velocity): Current rate of change.
//
// Each frame, acceleration is computed from forces, then integrated to update velocity
// and position using Euler integration.
//
// # Spring Configuration
//
// The `config` field accepts a SpringCfg with these parameters:
// - `stiffness` (default 100): Controls snap/responsiveness. Higher values make the
//   spring reach the target faster but with more potential overshoot.
// - `damping` (default 10): Controls oscillation decay. Higher values reduce bounce.
//   Critical damping (no oscillation) occurs when damping² = 4 * stiffness * mass.
// - `mass` (default 1.0): Inertia of the animated value. Higher mass means slower
//   acceleration and more momentum (harder to stop/reverse).
// - `threshold` (default 0.01): Settling tolerance. Animation stops when both velocity
//   and displacement are below this value.
//
// # Presets
//
// Four built-in presets cover common use cases:
// - `spring_default`: Balanced general-purpose spring (stiffness: 100, damping: 10)
// - `spring_gentle`: Slow, smooth with minimal overshoot (stiffness: 50, damping: 8)
// - `spring_bouncy`: Lively with noticeable oscillation (stiffness: 300, damping: 15)
// - `spring_stiff`: Fast and snappy, minimal bounce (stiffness: 500, damping: 30)
//
// # Fields
//
// - `id`: Unique identifier (required). Used for animation replacement/lookup.
// - `config`: Spring physics parameters (default spring_default).
// - `on_value`: Callback invoked each frame with current position (required).
// - `on_done`: Optional callback when spring settles at rest.
// - `state`: Internal physics state (position, velocity, target, at_rest).
//
// # Initialization
//
// IMPORTANT: You must call `spring_to(from, to)` before adding the animation to set
// the initial position and target. Without this call, the spring starts at position 0
// with target 0 and won't animate.
//
// ```
// mut spring := gui.SpringAnimation{
//     id:       'sidebar'
//     config:   gui.spring_bouncy
//     on_value: fn (v f32, mut w gui.Window) { ... }
// }
// spring.spring_to(0, 200)  // REQUIRED: set from/to values
// w.animation_add(mut spring)
// ```
//
// # Methods
//
// - `spring_to(from, to)`: Initialize spring at `from` position targeting `to`. Resets
//   velocity to zero. Call before adding animation or to restart from a new position.
// - `retarget(to)`: Change target while preserving current position and velocity. Use
//   this for smooth interruption - the spring will naturally curve toward the new
//   target without jarring direction changes.
//
// # Example: Sidebar Toggle
//
// ```
// fn toggle_sidebar(mut w gui.Window) {
//     state := w.state[MyState]()
//     target := if state.sidebar_open { f32(0) } else { f32(250) }
//
//     mut spring := gui.SpringAnimation{
//         id:       'sidebar_width'
//         config:   gui.spring_stiff
//         on_value: fn (v f32, mut w gui.Window) {
//             mut s := w.state[MyState]()
//             s.sidebar_width = v
//         }
//         on_done: fn (mut w gui.Window) {
//             mut s := w.state[MyState]()
//             s.sidebar_open = !s.sidebar_open
//         }
//     }
//     spring.spring_to(state.sidebar_width, target)
//     w.animation_add(mut spring)
// }
// ```
//
// # Example: Interruptible Drag
//
// ```
// fn on_drag_end(mut w gui.Window, release_x f32) {
//     // Spring back to nearest snap point
//     snap_x := f32(int((release_x + 50) / 100) * 100)
//
//     if existing := w.animation_get[gui.SpringAnimation]('drag_spring') {
//         // Smoothly redirect existing spring (preserves momentum)
//         existing.retarget(snap_x)
//     } else {
//         mut spring := gui.SpringAnimation{
//             id:       'drag_spring'
//             config:   gui.spring_bouncy
//             on_value: fn (v f32, mut w gui.Window) { ... }
//         }
//         spring.spring_to(release_x, snap_x)
//         w.animation_add(mut spring)
//     }
// }
// ```
//
// # When to Use Springs vs Tweens
//
// Use SpringAnimation when:
// - Motion should feel physical and organic
// - Animation may be interrupted and redirected
// - You want natural overshoot/bounce
// - Duration should be determined by physics, not predetermined
//
// Use TweenAnimation when:
// - You need precise timing (e.g., synchronized with audio)
// - Animation must complete in exact duration
// - Linear or eased motion is preferred over bouncy
// - Simpler setup without physics tuning
pub struct SpringAnimation implements Animation {
pub:
	id       string @[required]
	config   SpringCfg = spring_default
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
