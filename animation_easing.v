module gui

import math

// EasingFn maps progress t (0.0 to 1.0) to an eased value.
// Use with TweenAnimation to control motion curves.
pub type EasingFn = fn (f32) f32

// ease_linear returns constant-speed motion with no acceleration.
pub fn ease_linear(t f32) f32 {
	return t
}

// ease_in_quad starts slow and accelerates (quadratic curve).
pub fn ease_in_quad(t f32) f32 {
	return t * t
}

// ease_out_quad starts fast and decelerates (quadratic curve).
pub fn ease_out_quad(t f32) f32 {
	return 1 - (1 - t) * (1 - t)
}

// ease_in_out_quad accelerates then decelerates (quadratic curve).
pub fn ease_in_out_quad(t f32) f32 {
	return if t < 0.5 { 2 * t * t } else { 1 - f32(math.pow(-2 * t + 2, 2)) / 2 }
}

// ease_in_cubic starts slow and accelerates (cubic curve, smoother than quad).
pub fn ease_in_cubic(t f32) f32 {
	return t * t * t
}

// ease_out_cubic starts fast and decelerates (cubic curve, smoother than quad).
pub fn ease_out_cubic(t f32) f32 {
	u := 1 - t
	return 1 - u * u * u
}

// ease_in_out_cubic accelerates then decelerates (cubic curve).
pub fn ease_in_out_cubic(t f32) f32 {
	return if t < 0.5 { 4 * t * t * t } else { 1 - f32(math.pow(-2 * t + 2, 3)) / 2 }
}

// ease_in_back pulls back slightly before accelerating forward.
pub fn ease_in_back(t f32) f32 {
	c1 := f32(1.70158)
	c3 := c1 + 1
	return c3 * t * t * t - c1 * t * t
}

// ease_out_back overshoots the target then settles back.
pub fn ease_out_back(t f32) f32 {
	c1 := f32(1.70158)
	c3 := c1 + 1
	return 1 + c3 * f32(math.pow(t - 1, 3)) + c1 * f32(math.pow(t - 1, 2))
}

// ease_out_elastic overshoots and oscillates like a released spring.
pub fn ease_out_elastic(t f32) f32 {
	if t == 0 {
		return 0
	}
	if t == 1 {
		return 1
	}
	c4 := f32(2 * math.pi) / 3
	return f32(math.pow(2, -10 * t)) * f32(math.sin((t * 10 - 0.75) * c4)) + 1
}

// ease_out_bounce simulates a bouncing ball settling to rest.
pub fn ease_out_bounce(t f32) f32 {
	n1 := f32(7.5625)
	d1 := f32(2.75)
	mut t_ := t

	if t_ < 1 / d1 {
		return n1 * t_ * t_
	} else if t_ < 2 / d1 {
		t_ -= 1.5 / d1
		return n1 * t_ * t_ + 0.75
	} else if t_ < 2.5 / d1 {
		t_ -= 2.25 / d1
		return n1 * t_ * t_ + 0.9375
	} else {
		t_ -= 2.625 / d1
		return n1 * t_ * t_ + 0.984375
	}
}

// cubic_bezier creates a custom easing function from bezier control points.
// Works like CSS cubic-bezier(). Common presets:
//   ease:        cubic_bezier(0.25, 0.1, 0.25, 1.0)
//   ease-in:     cubic_bezier(0.42, 0, 1.0, 1.0)
//   ease-out:    cubic_bezier(0, 0, 0.58, 1.0)
//   ease-in-out: cubic_bezier(0.42, 0, 0.58, 1.0)
pub fn cubic_bezier(x1 f32, y1 f32, x2 f32, y2 f32) EasingFn {
	return fn [x1, y1, x2, y2] (t f32) f32 {
		return bezier_calc(t, x1, y1, x2, y2)
	}
}

// bezier_calc approximates cubic bezier curve value
fn bezier_calc(t f32, x1 f32, y1 f32, x2 f32, y2 f32) f32 {
	// Newton-Raphson iteration to find t for x
	mut guess := t
	for _ in 0 .. 8 {
		x := bezier_x(guess, x1, x2) - t
		if f32_abs(x) < 0.001 {
			break
		}
		dx := bezier_dx(guess, x1, x2)
		if f32_abs(dx) < 0.000001 {
			break
		}
		guess -= x / dx
	}
	return bezier_y(guess, y1, y2)
}

fn bezier_x(t f32, x1 f32, x2 f32) f32 {
	return 3 * (1 - t) * (1 - t) * t * x1 + 3 * (1 - t) * t * t * x2 + t * t * t
}

fn bezier_y(t f32, y1 f32, y2 f32) f32 {
	return 3 * (1 - t) * (1 - t) * t * y1 + 3 * (1 - t) * t * t * y2 + t * t * t
}

fn bezier_dx(t f32, x1 f32, x2 f32) f32 {
	return 3 * (1 - t) * (1 - t) * x1 + 6 * (1 - t) * t * (x2 - x1) + 3 * t * t * (1 - x2)
}

// lerp linearly interpolates between a and b by t
@[inline]
pub fn lerp(a f32, b f32, t f32) f32 {
	return a + (b - a) * t
}
