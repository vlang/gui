module gui

// layout_sizing.v implements the size-distribution pass of the layout pipeline.
// DistributeMode/DistributeAxis enums control grow vs shrink and horizontal vs
// vertical axes. The single distribute_space() algorithm handles both axes,
// using get_size/set_size/get_min_size accessor helpers to stay generic.
// Called from layout_arrange (layout_position.v) before position assignment.

// DistributeMode controls whether space distribution grows or shrinks children.
enum DistributeMode as u8 {
	grow
	shrink
}

// DistributeAxis selects the dimension for space distribution.
enum DistributeAxis as u8 {
	horizontal
	vertical
}

struct DistributeScratch {
mut:
	candidates                 []int
	fixed_indices              []int
	parent_total_child_widths  map[u64]f32
	parent_total_child_heights map[u64]f32
}

@[inline]
fn (mut scratch DistributeScratch) ensure_cap(size int) {
	if scratch.candidates.cap < size {
		scratch.candidates = []int{cap: size}
	} else {
		scratch.candidates.clear()
	}
	if scratch.fixed_indices.cap < size {
		scratch.fixed_indices = []int{cap: size}
	} else {
		scratch.fixed_indices.clear()
	}
}

// Dimension accessor functions abstract over the horizontal/vertical axis
// to enable a single unified algorithm for both directions.

@[inline]
fn get_size(shape &Shape, axis DistributeAxis) f32 {
	return match axis {
		.horizontal { shape.width }
		.vertical { shape.height }
	}
}

@[inline]
fn set_size(mut shape Shape, axis DistributeAxis, value f32) {
	match axis {
		.horizontal { shape.width = value }
		.vertical { shape.height = value }
	}
}

@[inline]
fn get_min_size(shape &Shape, axis DistributeAxis) f32 {
	return match axis {
		.horizontal { shape.min_width }
		.vertical { shape.min_height }
	}
}

@[inline]
fn get_max_size(shape &Shape, axis DistributeAxis) f32 {
	return match axis {
		.horizontal { shape.max_width }
		.vertical { shape.max_height }
	}
}

@[inline]
fn get_sizing(shape &Shape, axis DistributeAxis) SizingType {
	return match axis {
		.horizontal { shape.sizing.width }
		.vertical { shape.sizing.height }
	}
}

// distribute_space distributes remaining space among fill-sized children.
// For grow mode: smallest children grow first until they match the next-smallest.
// For shrink mode: largest children shrink first until they match the next-largest.
//
// The shrink algorithm also considers fixed children when finding the largest,
// which prevents fill children from shrinking below their fixed siblings.
//
// Returns the remaining space after distribution (for verification).
struct DistributionState {
mut:
	remaining      f32
	prev_remaining f32
	mode           DistributeMode
	axis           DistributeAxis
}

// DistributionExtrema stores one iteration's resize boundary pair.
// extremum is the active group size in the current mode:
// - grow: smallest fill child size
// - shrink: largest child size
// next_extrema is the nearest neighboring size used to cap delta.
// Sentinel values represent "no neighbor found":
// - grow: max_u32
// - shrink: 0
struct DistributionExtrema {
	extremum     f32
	next_extrema f32
}

fn collect_distribution_candidates(layout &Layout, axis DistributeAxis, mode DistributeMode, mut fill_indices []int, mut fixed_indices []int) {
	fill_indices.clear()
	if mode == .shrink {
		fixed_indices.clear()
	}
	for i, child in layout.children {
		if get_sizing(child.shape, axis) == .fill {
			fill_indices << i
		} else if mode == .shrink {
			fixed_indices << i
		}
	}
}

fn should_continue_distribution(state DistributionState, fill_count int) bool {
	if !f32_is_finite(state.remaining) {
		return false
	}
	if fill_count == 0 {
		return false
	}
	return match state.mode {
		.grow { state.remaining > f32_tolerance }
		.shrink { state.remaining < -f32_tolerance }
	}
}

fn find_distribution_extrema(layout &Layout, axis DistributeAxis, mode DistributeMode, fill_indices []int, fixed_indices []int) ?DistributionExtrema {
	if fill_indices.len == 0 {
		return none
	}
	mut extrema := get_size(layout.children[fill_indices[0]].shape, axis)
	mut next_extrema := match mode {
		.grow { f32(max_u32) } // sentinel: larger than any real value
		.shrink { f32(0) } // sentinel: smaller than any real value
	}
	for idx in fill_indices {
		child_size := get_size(layout.children[idx].shape, axis)
		match mode {
			.grow {
				if child_size < extrema {
					next_extrema = extrema
					extrema = child_size
				} else if child_size > extrema {
					next_extrema = f32_min(next_extrema, child_size)
				}
			}
			.shrink {
				if child_size > extrema {
					next_extrema = extrema
					extrema = child_size
				} else if child_size < extrema {
					next_extrema = f32_max(next_extrema, child_size)
				}
			}
		}
	}
	if mode == .shrink {
		for idx in fixed_indices {
			child_size := get_size(layout.children[idx].shape, axis)
			if child_size > extrema {
				next_extrema = extrema
				extrema = child_size
			} else if child_size < extrema {
				next_extrema = f32_max(next_extrema, child_size)
			}
		}
	}
	if !f32_is_finite(extrema) || !f32_is_finite(next_extrema) {
		return none
	}
	return DistributionExtrema{
		extremum:     extrema
		next_extrema: next_extrema
	}
}

fn compute_distribution_delta(layout &Layout, state DistributionState, extrema DistributionExtrema, fill_count int, fixed_count int) ?f32 {
	mut size_delta := match state.mode {
		.grow {
			if extrema.next_extrema == max_u32 {
				state.remaining
			} else {
				extrema.next_extrema - extrema.extremum
			}
		}
		.shrink {
			if extrema.extremum > 0 {
				if extrema.next_extrema == 0 {
					state.remaining
				} else {
					extrema.next_extrema - extrema.extremum
				}
			} else {
				state.remaining
			}
		}
	}
	if !f32_is_finite(size_delta) {
		return none
	}
	match state.mode {
		.grow {
			size_delta = f32_min(size_delta, state.remaining / fill_count)
		}
		.shrink {
			total_count := fill_count + fixed_count
			if total_count > 0 {
				size_delta = f32_max(size_delta, state.remaining / f32(total_count))
			}
		}
	}
	if !f32_is_finite(size_delta) {
		return none
	}
	mut sane_delta_limit := f32_max(f32_abs(get_size(layout.shape, state.axis)), f32_abs(state.remaining))
	sane_delta_limit = f32_max(sane_delta_limit * 4, 1_000_000)
	if !f32_is_finite(sane_delta_limit) || sane_delta_limit <= 0 {
		return none
	}
	return f32_clamp(size_delta, -sane_delta_limit, sane_delta_limit)
}

fn apply_distribution_delta(mut layout Layout, axis DistributeAxis, extremum f32, size_delta f32, remaining_in f32, mut fill_indices []int) ?f32 {
	mut remaining := remaining_in
	mut keep_idx := 0
	for i in 0 .. fill_indices.len {
		idx := fill_indices[i]
		mut child := &layout.children[idx]
		mut keep_child := true
		child_size := get_size(child.shape, axis)
		if child_size == extremum {
			prev_size := child_size
			new_size := child_size + size_delta
			if !f32_is_finite(new_size) {
				return none
			}
			set_size(mut child.shape, axis, new_size)

			mut constrained := false
			min_size := get_min_size(child.shape, axis)
			max_size := get_max_size(child.shape, axis)
			current_size := get_size(child.shape, axis)
			if current_size <= min_size {
				set_size(mut child.shape, axis, min_size)
				constrained = true
			} else if max_size > 0 && current_size >= max_size {
				set_size(mut child.shape, axis, max_size)
				constrained = true
			}
			remaining -= get_size(child.shape, axis) - prev_size
			if !f32_is_finite(remaining) {
				return none
			}
			if constrained {
				keep_child = false
			}
		}
		if keep_child {
			if keep_idx != i {
				fill_indices[keep_idx] = idx
			}
			keep_idx++
		}
	}
	fill_indices.trim(keep_idx)
	return remaining
}

fn distribute_space(mut layout Layout,
	remaining_in f32,
	mode DistributeMode,
	axis DistributeAxis,
	mut candidates []int,
	mut fixed_indices []int) f32 {
	if !f32_is_finite(remaining_in) {
		return f32(0)
	}
	mut state := DistributionState{
		remaining:      remaining_in
		prev_remaining: f32(0)
		mode:           mode
		axis:           axis
	}
	collect_distribution_candidates(layout, axis, mode, mut candidates, mut fixed_indices)

	for {
		if !should_continue_distribution(state, candidates.len) {
			break
		}
		if f32_are_close(state.remaining, state.prev_remaining) {
			break
		}
		state.prev_remaining = state.remaining
		extrema := find_distribution_extrema(layout, axis, mode, candidates, fixed_indices) or {
			break
		}
		size_delta := compute_distribution_delta(layout, state, extrema, candidates.len,
			fixed_indices.len) or { break }
		state.remaining = apply_distribution_delta(mut layout, axis, extrema.extremum,
			size_delta, state.remaining, mut candidates) or { break }
	}
	return state.remaining
}

// layout_widths arranges children horizontally. Only containers with an axis
// are processed.
fn layout_widths(mut layout Layout) {
	padding := layout.shape.padding_width()
	if layout.shape.axis == .left_to_right { // along the axis
		spacing := layout.spacing()
		if layout.shape.sizing.width == .fixed {
			for mut child in layout.children {
				layout_widths(mut child)
			}
		} else {
			mut min_widths := padding + spacing
			for mut child in layout.children {
				layout_widths(mut child)
				layout.shape.width += child.shape.width
				if layout.shape.wrap || layout.shape.overflow {
					// Wrap/overflow containers only need room for
					// the widest single child; the respective layout
					// pass handles the rest.
					min_widths = f32_max(min_widths, child.shape.width + padding)
				} else if !layout.shape.clip {
					min_widths += child.shape.min_width
				}
			}

			if !layout.shape.wrap && !layout.shape.overflow {
				layout.shape.min_width = f32_max(min_widths, layout.shape.min_width + padding +
					spacing)
			} else {
				layout.shape.min_width = f32_max(min_widths, layout.shape.min_width)
			}
			layout.shape.width += padding + spacing

			if layout.shape.max_width > 0 {
				layout.shape.width = f32_min(layout.shape.max_width, layout.shape.width)
				layout.shape.min_width = f32_min(layout.shape.max_width, layout.shape.min_width)
			}
			if layout.shape.min_width > 0 {
				layout.shape.width = f32_max(layout.shape.min_width, layout.shape.width)
			}
		}
	} else if layout.shape.axis == .top_to_bottom { // across the axis
		for mut child in layout.children {
			layout_widths(mut child)
			if layout.shape.sizing.width != .fixed {
				layout.shape.width = f32_max(layout.shape.width, child.shape.width + padding)
				// Clip containers hide overflow — children's min_width
				// must not force the container wider.
				if !layout.shape.clip {
					layout.shape.min_width = f32_max(layout.shape.min_width,
						child.shape.min_width + padding)
				}
			}
		}
		if layout.shape.min_width > 0 {
			layout.shape.width = f32_max(layout.shape.width, layout.shape.min_width)
		}
		if layout.shape.max_width > 0 {
			layout.shape.width = f32_min(layout.shape.width, layout.shape.max_width)
		}
	}
}

// layout_heights arranges children vertically. Only containers with an axis
// are processed.
fn layout_heights(mut layout Layout) {
	padding := layout.shape.padding_height()
	if layout.shape.axis == .top_to_bottom { // along the axis
		spacing := layout.spacing()
		if layout.shape.sizing.height == .fixed {
			for mut child in layout.children {
				layout_heights(mut child)
			}
		} else {
			mut min_heights := padding + spacing
			for mut child in layout.children {
				layout_heights(mut child)
				layout.shape.height += child.shape.height
				min_heights += child.shape.min_height
			}

			layout.shape.min_height = f32_max(min_heights, layout.shape.min_height + padding +
				spacing)
			layout.shape.height += padding + spacing

			if layout.shape.max_height > 0 {
				layout.shape.height = f32_min(layout.shape.max_height, layout.shape.height)
				layout.shape.min_height = f32_min(layout.shape.max_height, layout.shape.min_height)
			}
			if layout.shape.min_height > 0 {
				layout.shape.height = f32_max(layout.shape.min_height, layout.shape.height)
			}
			if layout.shape.sizing.height == .fill && layout.shape.id_scroll > 0 {
				layout.shape.min_height = spacing_small
			}
		}
	} else if layout.shape.axis == .left_to_right { // across the axis
		for mut child in layout.children {
			layout_heights(mut child)
			if layout.shape.sizing.height != .fixed {
				layout.shape.height = f32_max(layout.shape.height, child.shape.height + padding)
				layout.shape.min_height = f32_max(layout.shape.min_height, child.shape.min_height +
					padding)
			}
		}
		if layout.shape.min_height > 0 {
			layout.shape.height = f32_max(layout.shape.height, layout.shape.min_height)
		}
		if layout.shape.max_height > 0 {
			layout.shape.height = f32_min(layout.shape.height, layout.shape.max_height)
		}
	}
}

// layout_fill_widths manages horizontal growth/shrinkage to satisfy constraints.
//
// Algorithm invariants:
// - Children with sizing.width == .fill participate in space distribution
// - Growth: smallest children grow first until they match the next-smallest
// - Shrink: largest children shrink first until they match the next-largest
// - Termination guarantee: each iteration either reduces |remaining_width| by
//   at least f32_tolerance OR removes at least one candidate from the list
// - The previous_remaining check guards against infinite loops when rounding
//   prevents progress
fn layout_fill_widths(mut layout Layout) {
	mut scratch := DistributeScratch{}
	layout_fill_widths_with_scratch(mut layout, mut scratch)
}

fn layout_fill_widths_with_scratch(mut layout Layout, mut scratch DistributeScratch) {
	if layout.parent == unsafe { nil } {
		scratch.parent_total_child_widths.clear()
	}
	mut remaining_width := layout.shape.width - layout.shape.padding_width()

	scratch.ensure_cap(layout.children.len)

	if layout.shape.axis == .left_to_right {
		for mut child in layout.children {
			remaining_width -= child.shape.width
		}
		// fence post spacing
		remaining_width -= layout.spacing()

		// Grow if needed
		if remaining_width > f32_tolerance {
			remaining_width = distribute_space(mut layout, remaining_width, .grow, .horizontal, mut
				scratch.candidates, mut scratch.fixed_indices)
		}

		// Shrink if needed — skip for wrap/overflow containers;
		// layout_wrap/layout_overflow handle excess children.
		if remaining_width < -f32_tolerance && !layout.shape.wrap && !layout.shape.overflow {
			remaining_width = distribute_space(mut layout, remaining_width, .shrink, .horizontal, mut
				scratch.candidates, mut scratch.fixed_indices)
		}
	} else if layout.shape.axis == .top_to_bottom {
		if layout.shape.id_scroll > 0 && layout.shape.sizing.width == .fill
			&& layout.shape.scroll_mode != .vertical_only && layout.parent != unsafe { nil }
			&& layout.parent.shape.axis == .left_to_right {
			parent_uid := layout.parent.shape.uid
			total_child_width := scratch.parent_total_child_widths[parent_uid] or {
				mut total := f32(0)
				for sibling in layout.parent.children {
					total += sibling.shape.width
				}
				scratch.parent_total_child_widths[parent_uid] = total
				total
			}
			sibling_width_sum := total_child_width - layout.shape.width
			target_width := layout.parent.shape.width - sibling_width_sum - layout.parent.spacing() - layout.parent.shape.padding_width()
			layout.shape.width = f32_max(0, target_width)
		}
		if layout.shape.min_width > 0 && layout.shape.width < layout.shape.min_width {
			layout.shape.width = layout.shape.min_width
		}
		if layout.shape.max_width > 0 && layout.shape.width > layout.shape.max_width {
			layout.shape.width = layout.shape.max_width
		}
		for mut child in layout.children {
			if child.shape.sizing.width == .fill {
				child.shape.width = remaining_width
				if child.shape.min_width > 0 {
					child.shape.width = f32_max(child.shape.width, child.shape.min_width)
				}
				if child.shape.max_width > 0 {
					child.shape.width = f32_min(child.shape.width, child.shape.max_width)
				}
			}
		}
	}

	for mut child in layout.children {
		layout_fill_widths_with_scratch(mut child, mut scratch)
	}
}

// layout_fill_heights manages vertical growth/shrinkage to satisfy constraints.
// See layout_fill_widths for algorithm invariants (same logic, vertical axis).
fn layout_fill_heights(mut layout Layout) {
	mut scratch := DistributeScratch{}
	layout_fill_heights_with_scratch(mut layout, mut scratch)
}

fn layout_fill_heights_with_scratch(mut layout Layout, mut scratch DistributeScratch) {
	if layout.parent == unsafe { nil } {
		scratch.parent_total_child_heights.clear()
	}
	mut remaining_height := layout.shape.height - layout.shape.padding_height()

	scratch.ensure_cap(layout.children.len)

	if layout.shape.axis == .top_to_bottom {
		for mut child in layout.children {
			remaining_height -= child.shape.height
		}
		// fence post spacing
		remaining_height -= layout.spacing()

		// Grow if needed
		if remaining_height > f32_tolerance {
			remaining_height = distribute_space(mut layout, remaining_height, .grow, .vertical, mut
				scratch.candidates, mut scratch.fixed_indices)
		}

		// Shrink if needed
		if remaining_height < -f32_tolerance {
			remaining_height = distribute_space(mut layout, remaining_height, .shrink,
				.vertical, mut scratch.candidates, mut scratch.fixed_indices)
		}
	} else if layout.shape.axis == .left_to_right {
		if layout.shape.id_scroll > 0 && layout.shape.sizing.height == .fill
			&& layout.shape.scroll_mode != .horizontal_only && layout.parent != unsafe { nil }
			&& layout.parent.shape.axis == .top_to_bottom {
			parent_uid := layout.parent.shape.uid
			total_child_height := scratch.parent_total_child_heights[parent_uid] or {
				mut total := f32(0)
				for sibling in layout.parent.children {
					total += sibling.shape.height
				}
				scratch.parent_total_child_heights[parent_uid] = total
				total
			}
			sibling_height_sum := total_child_height - layout.shape.height
			target_height := layout.parent.shape.height - sibling_height_sum - layout.parent.spacing() - layout.parent.shape.padding_height()
			layout.shape.height = f32_max(0, target_height)
		}
		if layout.shape.min_height > 0 && layout.shape.height < layout.shape.min_height {
			layout.shape.height = layout.shape.min_height
		}
		if layout.shape.max_height > 0 && layout.shape.height > layout.shape.max_height {
			layout.shape.height = layout.shape.max_height
		}
		for mut child in layout.children {
			if child.shape.sizing.height == .fill {
				child.shape.height = remaining_height
				if child.shape.min_height > 0 {
					child.shape.height = f32_max(child.shape.height, child.shape.min_height)
				}
				if child.shape.max_height > 0 {
					child.shape.height = f32_min(child.shape.height, child.shape.max_height)
				}
			}
		}
	}

	for mut child in layout.children {
		layout_fill_heights_with_scratch(mut child, mut scratch)
	}
}
