module gui

// ------------------------------
// Tests for xtra_math.v helpers
// ------------------------------

// int_clamp returns x constrained between min and max
fn test_int_clamp_basic() {
	// Below min
	assert int_clamp(-10, 0, 5) == 0
	// Above max
	assert int_clamp(10, 0, 5) == 5
	// Within range
	assert int_clamp(3, 0, 5) == 3
}

fn test_int_clamp_boundaries() {
	// On boundaries should return the value itself
	assert int_clamp(0, 0, 5) == 0
	assert int_clamp(5, 0, 5) == 5
	// Negative ranges
	assert int_clamp(-3, -5, -1) == -3
	assert int_clamp(-10, -5, -1) == -5
	assert int_clamp(0, -5, -1) == -1
}

// f32_clamp returns x constrained between min and max
fn test_f32_clamp_basic() {
	// Below min
	assert f32_clamp(f32(-1.5), f32(0.0), f32(2.5)) == f32(0.0)
	// Above max
	assert f32_clamp(f32(3.14), f32(0.0), f32(2.5)) == f32(2.5)
	// Within range
	assert f32_clamp(f32(1.25), f32(0.0), f32(2.5)) == f32(1.25)
}

fn test_f32_clamp_boundaries() {
	// On boundaries should return the value itself
	assert f32_clamp(f32(0.0), f32(0.0), f32(2.0)) == f32(0.0)
	assert f32_clamp(f32(2.0), f32(0.0), f32(2.0)) == f32(2.0)
	// Negative ranges
	assert f32_clamp(f32(-3.0), f32(-5.0), f32(-1.0)) == f32(-3.0)
	assert f32_clamp(f32(-10.0), f32(-5.0), f32(-1.0)) == f32(-5.0)
	assert f32_clamp(f32(0.0), f32(-5.0), f32(-1.0)) == f32(-1.0)
}

// f32_are_close tests if |a - b| <= f32_tolerance (0.01)
fn test_f32_are_close_within_tolerance() {
	// Within tolerance
	assert f32_are_close(f32(1.00), f32(1.005))
	assert f32_are_close(f32(-2.50), f32(-2.507))
}

fn test_f32_are_close_at_tolerance_boundary() {
	// Almost at tolerance boundary should be considered close
	// Round-off errors prevent exact boundary condition
	assert f32_are_close(f32(10.00), f32(10.009))
	assert f32_are_close(f32(-3.33), f32(-3.339))
}

fn test_f32_are_close_outside_tolerance() {
	// Outside tolerance should be false
	assert !f32_are_close(f32(0.0), f32(0.02))
	assert !f32_are_close(f32(-1.0), f32(-1.02))
}
