module gui

import math

fn test_filter_texture_dims_from_bbox_valid() {
	dims := filter_texture_dims_from_bbox(12.2, 8.01, 1024)
	assert dims.valid
	assert dims.width == 13
	assert dims.height == 9
}

fn test_filter_texture_dims_from_bbox_rejects_invalid_values() {
	zero := filter_texture_dims_from_bbox(0.0, 10.0, 1024)
	neg := filter_texture_dims_from_bbox(-1.0, 10.0, 1024)
	inf := filter_texture_dims_from_bbox(f32(math.inf(1)), 10.0, 1024)
	assert !zero.valid
	assert !neg.valid
	assert !inf.valid
}

fn test_filter_texture_dims_from_bbox_rejects_oversize() {
	over := filter_texture_dims_from_bbox(2048.0, 16.0, 1024)
	assert !over.valid
}
