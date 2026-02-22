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

fn test_find_filter_bracket_range_finds_end() {
	renderers := [
		Renderer(DrawFilterBegin{}),
		Renderer(DrawRect{
			x:     1
			y:     2
			w:     3
			h:     4
			style: .fill
		}),
		Renderer(DrawFilterEnd{}),
		Renderer(DrawNone{}),
	]
	bracket := find_filter_bracket_range(renderers, 1)
	assert bracket.start_idx == 1
	assert bracket.end_idx == 2
	assert bracket.next_idx == 3
	assert bracket.found_end
}

fn test_find_filter_bracket_range_handles_missing_end() {
	renderers := [
		Renderer(DrawRect{
			x:     1
			y:     2
			w:     3
			h:     4
			style: .fill
		}),
		Renderer(DrawNone{}),
	]
	bracket := find_filter_bracket_range(renderers, 0)
	assert bracket.start_idx == 0
	assert bracket.end_idx == 2
	assert bracket.next_idx == 2
	assert !bracket.found_end
}

fn test_index_filter_bracket_ends_nested() {
	renderers := [
		Renderer(DrawFilterBegin{}), // 0
		Renderer(DrawRect{
			x:     1
			y:     1
			w:     1
			h:     1
			style: .fill
		}),
		Renderer(DrawFilterBegin{}), // 2
		Renderer(DrawFilterEnd{}), // 3
		Renderer(DrawFilterEnd{}), // 4
	]
	end_by_begin := index_filter_bracket_ends(renderers)
	end0 := end_by_begin[0] or { -1 }
	end2 := end_by_begin[2] or { -1 }
	assert end0 == 4
	assert end2 == 3
}
