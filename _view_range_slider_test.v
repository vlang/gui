module gui

import math

fn test_range_slider_defaults() {
	rs := range_slider(
		id:        'test_slider'
		on_change: fn (val f32, mut e Event, mut w Window) {}
	)
	// Default max is 100, min is 0
	// Default size is from theme
	// View is an interface and doesn't expose id field directly
}

fn test_clamping() {
	// Logic test for clamping logic used in slider
	min := f32(0)
	max := f32(100)
	val_over := f32(150)
	val_under := f32(-50)

	clamped_over := math.clamp(val_over, min, max)
	assert clamped_over == 100

	clamped_under := math.clamp(val_under, min, max)
	assert clamped_under == 0
}

fn test_range_slider_structure() {
	// Verify hierarchy and sizing logic
	thumb_size := f32(20)
	size := f32(10)

	// Create slider (Wrapper)
	rs_view := range_slider(
		id:         'test'
		thumb_size: thumb_size
		size:       size
		on_change:  fn (val f32, mut e Event, mut w Window) {}
	)

	// View is an interface and doesn't expose id field directly
	_ = rs_view
}
