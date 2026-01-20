module gui

// int_clamp returns x constrained between min and max
@[inline]
pub fn int_clamp(x int, min int, max int) int {
	if x < min {
		return min
	}
	if x > max {
		return max
	}
	return x
}

// f32_clamp returns x constrained min and max
@[inline]
pub fn f32_clamp(x f32, min f32, max f32) f32 {
	if x < min {
		return min
	}
	if x > max {
		return max
	}
	return x
}

// f32 values equal if within tolerance
pub const f32_tolerance = f32(0.01)

// f32_are_close tests if the difference of a and b is less than f32_tolerance
@[inline]
pub fn f32_are_close(a f32, b f32) bool {
	d := if a >= b { a - b } else { b - a }
	return d <= f32_tolerance
}

// u32_sort orders a and b in ascending order
fn u32_sort(a u32, b u32) (u32, u32) {
	return match b < a {
		true { b, a }
		else { a, b }
	}
}
