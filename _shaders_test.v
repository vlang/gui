module gui

import math

fn test_pack_shader_params() {
	// 10.0 px radius -> 40 fixed-point units.
	mut val := pack_shader_params(10.0, 0.0)
	assert val == 163840.0

	// 5.5 px radius, 2.0 px thickness.
	val = pack_shader_params(5.5, 2.0)
	assert val == 90120.0

	// 0 px radius, 10 px thickness.
	val = pack_shader_params(0.0, 10.0)
	assert val == 40.0

	// Reconstruction path mirrors shader decode.
	val = pack_shader_params(25.0, 15.5)
	unpacked_radius := math.floor(val / 4096.0) / 4.0
	unpacked_thickness := math.fmod(val, 4096.0) / 4.0

	assert unpacked_radius == 25.0
	assert unpacked_thickness == 15.5
}

fn test_pack_shader_params_clamps_to_max() {
	val := pack_shader_params(5000.0, 5000.0)
	assert val == 16777215.0
	unpacked_radius := math.floor(val / 4096.0) / 4.0
	unpacked_thickness := math.fmod(val, 4096.0) / 4.0
	assert unpacked_radius == 1023.75
	assert unpacked_thickness == 1023.75
}

fn test_normalize_gradient_stops_for_shader_clamps_and_sorts() {
	stops := [
		GradientStop{
			color: Color{255, 0, 0, 255}
			pos:   1.5
		},
		GradientStop{
			color: Color{0, 0, 255, 255}
			pos:   -0.25
		},
	]
	normalized := normalize_gradient_stops_for_shader(stops)
	assert normalized.len == 2
	assert normalized[0].pos == 0.0
	assert normalized[1].pos == 1.0
	assert normalized[0].color.b == 255
	assert normalized[1].color.r == 255
}

fn test_normalize_gradient_stops_for_shader_resamples_extra_stops() {
	stops := [
		GradientStop{
			color: Color{255, 0, 0, 255}
			pos:   0.0
		},
		GradientStop{
			color: Color{255, 255, 0, 255}
			pos:   0.2
		},
		GradientStop{
			color: Color{0, 255, 0, 255}
			pos:   0.4
		},
		GradientStop{
			color: Color{0, 255, 255, 255}
			pos:   0.6
		},
		GradientStop{
			color: Color{255, 0, 255, 255}
			pos:   0.8
		},
		GradientStop{
			color: Color{0, 0, 255, 255}
			pos:   1.0
		},
	]
	normalized := normalize_gradient_stops_for_shader(stops)
	assert normalized.len == gradient_shader_stop_limit
	assert normalized[0].pos == 0.0
	assert normalized[gradient_shader_stop_limit - 1].pos == 1.0
	assert normalized[gradient_shader_stop_limit - 1].color.b == 255
	assert normalized[gradient_shader_stop_limit - 1].color.r == 0
}
