module gui

import math

fn test_pack_shader_params() {
	// Test case 1: Radius 10, Thickness 0 (Filled)
	// packing_stride is 1000.0
	// expected: 0 + floor(10) * 1000 = 10000
	mut val := pack_shader_params(10.0, 0.0)
	assert val == 10000.0

	// Test case 2: Radius 5.5, Thickness 2.0
	// expected: 2.0 + floor(5.5) * 1000 = 2.0 + 5 * 1000 = 5002.0
	val = pack_shader_params(5.5, 2.0)
	assert val == 5002.0

	// Test case 3: Radius 0, Thickness 10
	// expected: 10 + 0 = 10
	val = pack_shader_params(0.0, 10.0)
	assert val == 10.0

	// Test case 4: Reconstruction
	// Simulates unpack logic in shader:
	// float radius = floor(params / 1000.0);
	// float thickness = mod(params, 1000.0);
	val = pack_shader_params(25.0, 15.5)

	unpacked_radius := math.floor(val / 1000.0)
	unpacked_thickness := math.fmod(val, 1000.0)

	assert unpacked_radius == 25.0
	assert unpacked_thickness == 15.5
}
