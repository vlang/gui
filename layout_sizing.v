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
	candidates    []int
	fixed_indices []int
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
fn distribute_space(mut layout Layout,
	remaining_in f32,
	mode DistributeMode,
	axis DistributeAxis,
	mut candidates []int,
	mut fixed_indices []int) f32 {
	mut remaining := remaining_in
	if !f32_is_finite(remaining) {
		return f32(0)
	}
	mut prev_remaining := f32(0)

	// Build candidate list
	candidates.clear()
	if mode == .shrink {
		fixed_indices.clear()
	}

	for i, child in layout.children {
		if get_sizing(child.shape, axis) == .fill {
			candidates << i
		} else if mode == .shrink {
			fixed_indices << i
		}
	}

	// Iterate until space is distributed or no candidates remain
	for {
		if !f32_is_finite(remaining) {
			break
		}
		// Check termination conditions based on mode
		should_continue := match mode {
			.grow { remaining > f32_tolerance && candidates.len > 0 }
			.shrink { remaining < -f32_tolerance && candidates.len > 0 }
		}
		if !should_continue {
			break
		}

		// Guard against infinite loops when rounding prevents progress
		if f32_are_close(remaining, prev_remaining) {
			break
		}
		prev_remaining = remaining

		// Find extremum based on mode
		mut extremum := get_size(layout.children[candidates[0]].shape, axis)
		mut second := match mode {
			.grow { f32(max_u32) } // sentinel: larger than any real value
			.shrink { f32(0) } // sentinel: smaller than any real value
		}

		for idx in candidates {
			child_size := get_size(layout.children[idx].shape, axis)
			match mode {
				.grow {
					if child_size < extremum {
						second = extremum
						extremum = child_size
					} else if child_size > extremum {
						second = f32_min(second, child_size)
					}
				}
				.shrink {
					if child_size > extremum {
						second = extremum
						extremum = child_size
					} else if child_size < extremum {
						second = f32_max(second, child_size)
					}
				}
			}
		}

		// For shrink mode, also consider fixed children when finding largest
		if mode == .shrink {
			for idx in fixed_indices {
				child_size := get_size(layout.children[idx].shape, axis)
				if child_size > extremum {
					second = extremum
					extremum = child_size
				} else if child_size < extremum {
					second = f32_max(second, child_size)
				}
			}
		}
		if !f32_is_finite(extremum) || !f32_is_finite(second) {
			break
		}

		// Calculate delta to add/remove
		mut delta := match mode {
			.grow {
				if second == max_u32 {
					remaining
				} else {
					second - extremum
				}
			}
			.shrink {
				if extremum > 0 {
					if second == 0 {
						remaining
					} else {
						second - extremum
					}
				} else {
					remaining
				}
			}
		}
		if !f32_is_finite(delta) {
			break
		}

		// Clamp delta based on mode and candidate count
		match mode {
			.grow {
				delta = f32_min(delta, remaining / candidates.len)
			}
			.shrink {
				total_len := candidates.len + fixed_indices.len
				if total_len > 0 {
					delta = f32_max(delta, remaining / f32(total_len))
				}
			}
		}
		if !f32_is_finite(delta) {
			break
		}
		mut sane_delta_limit := f32_max(f32_abs(get_size(layout.shape, axis)), f32_abs(remaining))
		sane_delta_limit = f32_max(sane_delta_limit * 4, 1_000_000)
		if !f32_is_finite(sane_delta_limit) || sane_delta_limit <= 0 {
			break
		}
		delta = f32_clamp(delta, -sane_delta_limit, sane_delta_limit)

		// Apply delta to candidates at extremum
		mut keep_idx := 0
		mut invalid_math := false
		for i in 0 .. candidates.len {
			idx := candidates[i]
			mut child := &layout.children[idx]
			mut kept := true

			child_size := get_size(child.shape, axis)
			if child_size == extremum {
				prev_size := child_size
				new_size := child_size + delta
				if !f32_is_finite(new_size) {
					invalid_math = true
					break
				}
				set_size(mut child.shape, axis, new_size)

				// Apply constraints
				mut constrained := false
				min_size := get_min_size(child.shape, axis)
				max_size := get_max_size(child.shape, axis)
				current := get_size(child.shape, axis)

				if current <= min_size {
					set_size(mut child.shape, axis, min_size)
					constrained = true
				} else if max_size > 0 && current >= max_size {
					set_size(mut child.shape, axis, max_size)
					constrained = true
				}

				remaining -= (get_size(child.shape, axis) - prev_size)
				if !f32_is_finite(remaining) {
					invalid_math = true
					break
				}

				if constrained {
					kept = false
				}
			}

			if kept {
				if keep_idx != i {
					candidates[keep_idx] = idx
				}
				keep_idx++
			}
		}
		if invalid_math {
			break
		}
		candidates.trim(keep_idx)
	}

	return remaining
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
			mut sibling_width_sum := f32(0)
			for sibling in layout.parent.children {
				if sibling.shape.uid != layout.shape.uid {
					sibling_width_sum += sibling.shape.width
				}
			}
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
			mut sibling_height_sum := f32(0)
			for sibling in layout.parent.children {
				if sibling.shape.uid != layout.shape.uid {
					sibling_height_sum += sibling.shape.height
				}
			}
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
