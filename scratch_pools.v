module gui

const scratch_filter_renderers_retain_max = 131_072
const scratch_filter_renderers_shrink_to = 8192
const scratch_floating_layouts_retain_max = 4096
const scratch_floating_layouts_shrink_to = 256
const scratch_floating_pool_retain_max = 512
const scratch_floating_pool_shrink_to = 64
const scratch_focus_candidates_retain_max = 4096
const scratch_focus_candidates_shrink_to = 512
const scratch_gradient_norm_retain_max = 64
const scratch_gradient_norm_shrink_to = 8
const scratch_svg_anim_vals_retain_max = 32
const scratch_svg_anim_vals_shrink_to = 8
const scratch_svg_group_matrices_retain_max = 256
const scratch_svg_group_opacities_retain_max = 256
const scratch_svg_tris_retain_max = 65_536
const scratch_svg_tris_shrink_to = 4096
const scratch_wrap_rows_retain_max = 4096
const scratch_wrap_rows_shrink_to = 256

struct WrapRowRange {
	start int
	end   int
}

struct ScratchPools {
mut:
	distribute            DistributeScratch
	filter_renderers      []Renderer
	floating_layouts      []&Layout
	floating_layout_pool  []&Layout
	floating_pool_used    int
	focus_candidates      []FocusCandidate
	gradient_norm_stops   []GradientStop
	gradient_sample_stops []GradientStop
	svg_anim_vals         []f32
	svg_group_matrices    map[string][6]f32
	svg_group_opacities   map[string]f32
	svg_transform_tris    []f32
	wrap_rows             []WrapRowRange
}

@[inline]
fn (mut pools ScratchPools) take_filter_renderers(required_cap int) []Renderer {
	mut scratch := unsafe { pools.filter_renderers }
	array_clear(mut scratch)
	if scratch.cap < required_cap {
		scratch = []Renderer{cap: required_cap}
	}
	return scratch
}

@[inline]
fn (mut pools ScratchPools) put_filter_renderers(mut scratch []Renderer) {
	if scratch.cap > scratch_filter_renderers_retain_max {
		scratch = []Renderer{cap: scratch_filter_renderers_shrink_to}
	}
	pools.filter_renderers = scratch
}

@[inline]
fn (mut pools ScratchPools) take_floating_layouts(required_cap int) []&Layout {
	mut scratch := unsafe { pools.floating_layouts }
	array_clear(mut scratch)
	if scratch.cap < required_cap {
		scratch = []&Layout{cap: required_cap}
	}
	pools.floating_pool_used = 0
	return scratch
}

@[inline]
fn (mut pools ScratchPools) alloc_floating_layout(src Layout) &Layout {
	idx := pools.floating_pool_used
	pools.floating_pool_used++
	if idx < pools.floating_layout_pool.len {
		mut reused := pools.floating_layout_pool[idx]
		unsafe {
			*reused = src
		}
		return reused
	}
	mut allocated := &Layout{
		...src
	}
	pools.floating_layout_pool << allocated
	return allocated
}

@[inline]
fn (mut pools ScratchPools) put_floating_layouts(mut scratch []&Layout) {
	if scratch.cap > scratch_floating_layouts_retain_max {
		scratch = []&Layout{cap: scratch_floating_layouts_shrink_to}
	}
	pools.floating_layouts = scratch
	if pools.floating_layout_pool.len > scratch_floating_pool_retain_max {
		pools.floating_layout_pool = pools.floating_layout_pool[..scratch_floating_pool_shrink_to].clone()
	}
}

@[inline]
fn (mut pools ScratchPools) take_focus_candidates() []FocusCandidate {
	mut scratch := unsafe { pools.focus_candidates }
	array_clear(mut scratch)
	return scratch
}

@[inline]
fn (mut pools ScratchPools) put_focus_candidates(mut scratch []FocusCandidate) {
	if scratch.cap > scratch_focus_candidates_retain_max {
		scratch = []FocusCandidate{cap: scratch_focus_candidates_shrink_to}
	}
	pools.focus_candidates = scratch
}

@[inline]
fn (mut pools ScratchPools) take_gradient_norm_stops(required_cap int) []GradientStop {
	mut scratch := unsafe { pools.gradient_norm_stops }
	scratch.clear()
	if scratch.cap < required_cap {
		scratch = []GradientStop{cap: required_cap}
	}
	return scratch
}

@[inline]
fn (mut pools ScratchPools) put_gradient_norm_stops(mut scratch []GradientStop) {
	if scratch.cap > scratch_gradient_norm_retain_max {
		scratch = []GradientStop{cap: scratch_gradient_norm_shrink_to}
	}
	pools.gradient_norm_stops = scratch
}

@[inline]
fn (mut pools ScratchPools) take_gradient_sample_stops(required_cap int) []GradientStop {
	mut scratch := unsafe { pools.gradient_sample_stops }
	scratch.clear()
	if scratch.cap < required_cap {
		scratch = []GradientStop{cap: required_cap}
	}
	return scratch
}

@[inline]
fn (mut pools ScratchPools) put_gradient_sample_stops(mut scratch []GradientStop) {
	if scratch.cap > gradient_shader_stop_limit {
		scratch = []GradientStop{cap: gradient_shader_stop_limit}
	}
	pools.gradient_sample_stops = scratch
}

@[inline]
fn (mut pools ScratchPools) take_svg_anim_vals() []f32 {
	mut scratch := unsafe { pools.svg_anim_vals }
	scratch.clear()
	return scratch
}

@[inline]
fn (mut pools ScratchPools) put_svg_anim_vals(mut scratch []f32) {
	if scratch.cap > scratch_svg_anim_vals_retain_max {
		scratch = []f32{cap: scratch_svg_anim_vals_shrink_to}
	}
	pools.svg_anim_vals = scratch
}

@[inline]
fn (mut pools ScratchPools) trim_svg_group_maps() {
	if pools.svg_group_matrices.len > scratch_svg_group_matrices_retain_max {
		pools.svg_group_matrices = map[string][6]f32{}
	}
	if pools.svg_group_opacities.len > scratch_svg_group_opacities_retain_max {
		pools.svg_group_opacities = map[string]f32{}
	}
}

@[inline]
fn (mut pools ScratchPools) take_svg_transform_tris() []f32 {
	mut scratch := unsafe { pools.svg_transform_tris }
	scratch.clear()
	return scratch
}

@[inline]
fn (mut pools ScratchPools) put_svg_transform_tris(mut scratch []f32) {
	if scratch.cap > scratch_svg_tris_retain_max {
		scratch = []f32{cap: scratch_svg_tris_shrink_to}
	}
	pools.svg_transform_tris = scratch
}

@[inline]
fn (mut pools ScratchPools) take_wrap_rows(required_cap int) []WrapRowRange {
	mut scratch := unsafe { pools.wrap_rows }
	array_clear(mut scratch)
	if scratch.cap < required_cap {
		scratch = []WrapRowRange{cap: required_cap}
	}
	return scratch
}

@[inline]
fn (mut pools ScratchPools) put_wrap_rows(mut scratch []WrapRowRange) {
	if scratch.cap > scratch_wrap_rows_retain_max {
		scratch = []WrapRowRange{cap: scratch_wrap_rows_shrink_to}
	}
	pools.wrap_rows = scratch
}
