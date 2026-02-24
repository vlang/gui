module gui

// Static source scan: flags .clear() calls that are not in the
// allowlist. Forces developers to explicitly declare new .clear()
// usage as GC-safe. See CLAUDE.md "GC / Boehm False-Retention Rules".
import os

// Allowlist entry: file path suffix + context snippet on same line.
// Keyed on content rather than line numbers so it survives refactors.
struct ClearAllowEntry {
	file_suffix string // e.g. 'scratch_pools.v' or 'svg/animation.v'
	context     string // substring that must appear on the .clear() line
}

// Every .clear() in the codebase must match one of these entries
// or the test fails. To add a new .clear(), append an entry here
// with a comment explaining why it is GC-safe.
const clear_allowlist = [
	// --- Value-only arrays (no pointers in backing memory) ---
	// []f32
	ClearAllowEntry{'scratch_pools.v', 'scratch.clear()'},
	ClearAllowEntry{'scratch_pools.v', 'out.clear()'},
	ClearAllowEntry{'render_svg.v', 'out.clear()'},
	ClearAllowEntry{'svg/animation.v', 'out.clear()'},
	// []int
	ClearAllowEntry{'layout_sizing.v', 'fill_indices.clear()'},
	ClearAllowEntry{'layout_sizing.v', 'fixed_indices.clear()'},
	ClearAllowEntry{'layout_sizing.v', 'scratch.candidates.clear()'},
	ClearAllowEntry{'layout_sizing.v', 'scratch.fixed_indices.clear()'},
	// []GradientStop (value struct: f32 + Color)
	ClearAllowEntry{'render_gradient.v', 'normalized.clear()'},
	ClearAllowEntry{'render_gradient.v', 'sampled.clear()'},
	// []FilterVertex (value struct: floats + u8s)
	ClearAllowEntry{'render_filters.v', 'scratch_vertices.clear()'},
	// []rune field (string builder, value type)
	ClearAllowEntry{'view_text_xtra.v', 'field.clear()'},
	// --- Map clears (map.clear() zeroes bucket metadata) ---
	// map[K]V — all safe: maps use internal hash tables
	ClearAllowEntry{'bounded_map.v', 'm.data.clear()'},
	ClearAllowEntry{'bounded_map.v', 'm.access_time.clear()'},
	ClearAllowEntry{'state_registry.v', 'r.maps.clear()'},
	ClearAllowEntry{'state_registry.v', 'r.meta.clear()'},
	ClearAllowEntry{'state_registry.v', 'r.orders.clear()'},
	ClearAllowEntry{'render_svg.v', 'svg_group_matrices.clear()'},
	ClearAllowEntry{'render_svg.v', 'svg_group_opacities.clear()'},
	ClearAllowEntry{'view_image_xtra.v', 'm.data.clear()'},
	ClearAllowEntry{'markdown_mermaid.v', 'm.data.clear()'},
	ClearAllowEntry{'markdown_mermaid.v', 'm.order.clear()'},
	ClearAllowEntry{'layout_sizing.v', 'parent_total_child_widths.clear()'},
	ClearAllowEntry{'layout_sizing.v', 'parent_total_child_heights.clear()'},
	ClearAllowEntry{'layout_query.v', 'focus_seen.clear()'},
	// --- BoundedMap/BoundedStack .clear() methods ---
	// These are the clear() method bodies themselves on the
	// wrapper types — internal map/array clears, not raw arrays.
	ClearAllowEntry{'bounded_stack.v', 's.elements.clear()'},
	// --- BoundedMap-backed state_map .clear() calls ---
	// state_map returns &BoundedMap whose .clear() method is safe
	ClearAllowEntry{'window_event.v', 'ss.clear()'},
	ClearAllowEntry{'window_event.v', 'cs.clear()'},
	ClearAllowEntry{'view_select.v', 'ss.clear()'},
	ClearAllowEntry{'view_overflow_panel.v', 'ss.clear()'},
	ClearAllowEntry{'view_input_date.v', 'ids.clear()'},
	ClearAllowEntry{'view_table.v', 'tc.clear()'},
	ClearAllowEntry{'view_state.v', 'diagram_cache.clear()'},
	ClearAllowEntry{'view_state.v', 'svg_cache.clear()'},
	ClearAllowEntry{'view_state.v', 'markdown_cache.clear()'},
	ClearAllowEntry{'view_state.v', 'registry.clear()'},
	ClearAllowEntry{'window_api.v', 'markdown_cache.clear()'},
	ClearAllowEntry{'window_api.v', 'diagram_cache.clear()'},
	ClearAllowEntry{'svg_load.v', 'svg_cache.clear()'},
	// --- FormIssue arrays (value struct: two strings, no ptrs) ---
	ClearAllowEntry{'view_form.v', 'sync_errors.clear()'},
	ClearAllowEntry{'view_form.v', 'async_errors.clear()'},
]

fn test_no_unallowlisted_clear_calls() {
	gui_root := os.dir(@FILE)
	mut violations := []string{}

	scan_dir(gui_root, '', mut violations)
	scan_dir(os.join_path(gui_root, 'svg'), 'svg/', mut violations)

	if violations.len > 0 {
		mut msg := '\n.clear() calls not in allowlist '
		msg += '(use array_clear for pointer arrays):\n'
		for v in violations {
			msg += '  ${v}\n'
		}
		msg += '\nAdd to clear_allowlist in _gc_lint_test.v '
		msg += 'if verified GC-safe.'
		assert false, msg
	}
}

fn scan_dir(dir string, prefix string, mut violations []string) {
	if !os.is_dir(dir) {
		return
	}
	entries := os.ls(dir) or { return }
	for fname in entries {
		if !fname.ends_with('.v') {
			continue
		}
		// Skip test files — they don't ship in the library
		if fname.ends_with('_test.v') {
			continue
		}
		rel := prefix + fname
		fpath := os.join_path(dir, fname)
		lines := os.read_lines(fpath) or { continue }
		for i, line in lines {
			trimmed := line.trim_space()
			if !trimmed.contains('.clear()') {
				continue
			}
			if trimmed.starts_with('//') {
				continue
			}
			if is_clear_allowed(rel, trimmed) {
				continue
			}
			violations << '${rel}:${i + 1}: ${trimmed}'
		}
	}
}

fn is_clear_allowed(rel_path string, line string) bool {
	for entry in clear_allowlist {
		if rel_path == entry.file_suffix && line.contains(entry.context) {
			return true
		}
	}
	return false
}
