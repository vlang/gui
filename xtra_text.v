module gui

// This module provides text manipulation utilities for the GUI framework, including:
// - Text measurement and width calculation functions
// - Text wrapping with different modes (simple, space-preserving)
// - Word and line position navigation
// - Text splitting and processing functions
// - Clipboard integration for text operations
//
import clipboard
import encoding.utf8
import hash.fnv1a

pub fn get_text_width_no_cache(text string, text_style TextStyle, window &Window) f32 {
	cfg := to_vglyph_cfg(text_style.to_text_cfg())
	return unsafe { window.text_system.text_width(text, cfg) or { 0 } }
}

// get_text_width calculates the width of a given text based on its style and window configuration,
// leveraging a caching mechanism to optimize performance.
pub fn get_text_width(text string, text_style TextStyle, mut window Window) f32 {
	htx := fnv1a.sum32_struct(text_style).str()
	text_htx := text + htx
	key := fnv1a.sum32_string(text_htx)
	return window.view_state.text_widths[key] or {
		cfg := to_vglyph_cfg(text_style.to_text_cfg())
		t_width := window.text_system.text_width(text, cfg) or { 0 }
		window.view_state.text_widths[key] = t_width
		t_width
	}
}

// text_width measures the visual width of the shape's lines, mirroring render rules:
// - when in password mode (and not placeholder), measure '*' repeated for visible rune count
fn text_width(shape &Shape, mut window Window) f32 {
	mut max_width := f32(0)
	htx := fnv1a.sum32_struct(shape.text_style).str()
	for line in shape.text_lines {
		mut effective := line
		// Mirror password masking used in render so measurement matches drawing
		if shape.text_is_password && !shape.text_is_placeholder {
			// Replace content with repeated password_char for the number of visible UTF-8 runes
			effective = password_char.repeat(utf8_str_visible_length(effective))
		}

		line_htx := effective + htx
		key := fnv1a.sum32_string(line_htx)
		width := window.view_state.text_widths[key] or {
			cfg := to_vglyph_cfg(shape.text_style.to_text_cfg())
			t_width := window.text_system.text_width(effective, cfg) or { 0 }
			t_width
		}
		max_width = f32_max(width, max_width)
	}
	return max_width
}

@[inline]
fn text_height(shape &Shape, mut window Window) f32 {
	lh := line_height(shape, mut window)
	return lh * shape.text_lines.len
}

@[inline]
fn line_height(shape &Shape, mut window Window) f32 {
	cfg := to_vglyph_cfg(shape.text_style.to_text_cfg())
	height := window.text_system.font_height(cfg)
	return height + shape.text_style.line_spacing
}

// text_wrap applies text wrapping logic to a given shape based on its text mode.
fn text_wrap(mut shape Shape, mut window Window) {
	if shape.text_mode in [.wrap, .wrap_keep_spaces] && shape.shape_type == .text {
		style := shape.text_style
		width := shape.width - shape.padding.width()
		tab_size := shape.text_tab_size
		shape.text_lines = match shape.text_mode == .wrap_keep_spaces {
			true { wrap_text_keep_spaces(shape.text, style, width, tab_size, mut window) }
			else { wrap_text_shrink_spaces(shape.text, style, width, tab_size, mut window) }
		}
		lh := line_height(shape, mut window)
		shape.height = shape.text_lines.len * lh
		shape.max_height = shape.height
		shape.min_height = shape.height
	} else if shape.text_mode in [.wrap, .wrap_keep_spaces] && shape.shape_type == .rtf {
		width := shape.width - shape.padding.width()
		tab_size := shape.text_tab_size
		shape.text_spans = rtf_wrap_text(shape.text_spans, width, tab_size, mut window)
		shape.width, shape.height = spans_size(shape.text_spans)
	}
}

// wrap_text_shrink_spaces wraps lines to given width (logical units, not chars)
// Extra white space is removed.
fn wrap_text_shrink_spaces(s string, text_style TextStyle, width f32, tab_size u32, mut window Window) []string {
	mut line := ''
	mut wrap := []string{cap: 10}
	unsafe { wrap.flags.set(.noslices) }
	for field in split_text(s, tab_size) {
		if field == '\n' {
			wrap << line + '\n'
			line = ''
			continue
		}
		if field.is_blank() {
			continue
		}
		if line.len == 0 {
			line = field + ' '
			continue
		}
		n_line := line + field + ' '
		t_width := get_text_width(n_line, text_style, mut window)
		if t_width > width {
			wrap << line
			line = field + ' '
		} else {
			line = n_line
		}
	}
	wrap << line.substr(0, int_max(0, line.len - 1))
	return wrap
}

// wrap_text_keep_spaces wraps lines to given width (logical units, not chars) White space is preserved
// 1. Preserves original spaces - No new spaces are added, only existing spaces from the input text are used
// 2. Tries to leave at least one space at the end - When wrapping is needed, it attempts to include
//    trailing spaces from the next field if they fit within the width limit
// 3. Splits multiple spaces appropriately - If a space field contains multiple spaces, it includes
//    as many as will fit and carries the rest to the next line
// 4. Wraps earlier when necessary - If no trailing spaces can be added, it tries to wrap at an earlier space
//    within the current line to ensure a space at the end
// 5. Respects width constraints - Never exceeds the specified width limit
// 6. Handles edge cases - Properly handles empty lines and overly long fields to avoid infinite loops
fn wrap_text_keep_spaces(text string, text_style TextStyle, max_width f32, tab_size u32, mut window Window) []string {
	mut current_line := ''
	mut lines := []string{cap: 10}
	unsafe { lines.flags.set(.noslices) }

	mut fields := split_text(text, tab_size)
	mut field_index := 0

	for field_index < fields.len {
		field := fields[field_index]
		is_newline_field := field == '\n'

		if is_newline_field {
			// Explicit newline: flush current line and start a new one
			lines << current_line + '\n'
			current_line = ''
			field_index++
			continue
		}

		candidate_line := current_line + field
		candidate_width := get_text_width(candidate_line, text_style, mut window)

		if candidate_width <= max_width {
			// Field fits on current line as-is
			current_line = candidate_line
			field_index++
			continue
		}

		// Candidate is too wide, need to consider wrapping
		mut output_line := current_line
		mut can_add_space := false
		is_line_non_empty := current_line.len > 0
		line_ends_with_space := current_line.ends_with(' ')
		has_next_field := field_index + 1 < fields.len

		// 0) If the current field is a whitespace block, try to split it so that
		//    as many spaces as possible are added to the current line without exceeding max_width.
		if field.is_blank() {
			mut spaces_to_add := ''
			for sp in field {
				test := current_line + spaces_to_add + sp.str()
				if get_text_width(test, text_style, mut window) <= max_width {
					spaces_to_add += sp.str()
				} else {
					break
				}
			}

			output_line = current_line + spaces_to_add

			// Update remaining spaces of the current field
			remaining := field[spaces_to_add.len..]
			if remaining.len > 0 {
				// Keep remaining spaces as the current field for next iteration
				fields[field_index] = remaining
			} else {
				// Fully consumed this space field
				field_index++
			}

			// Flush the decided output line even if it's empty (e.g., max_width == 0)
			lines << output_line
			current_line = ''
			continue
		}

		// 1) Try to add spaces from the next field (if it is a whitespace field)
		if is_line_non_empty && !line_ends_with_space && has_next_field {
			next_field := fields[field_index + 1]
			if next_field != '\n' && next_field.is_blank() {
				mut spaces_to_add := ''
				for space in next_field {
					test_line := current_line + spaces_to_add + space.str()
					test_width := get_text_width(test_line, text_style, mut window)
					if test_width <= max_width {
						spaces_to_add += space.str()
						can_add_space = true
					} else {
						break
					}
				}
				if can_add_space {
					output_line = current_line + spaces_to_add

					// Update remaining spaces in next field
					remaining_spaces := next_field[spaces_to_add.len..]
					if remaining_spaces.len > 0 {
						fields[field_index + 1] = remaining_spaces
					} else {
						// All spaces consumed, remove the next field
						fields.delete(field_index + 1)
					}
				}
			}
		}

		// 2) If space can't be added and line is non-empty & not ending with space,
		//    try to wrap earlier at a space.
		if !can_add_space && is_line_non_empty && !line_ends_with_space {
			mut should_wrap_early := false

			if current_line.contains(' ') {
				last_space_idx := current_line.last_index(' ') or { -1 }
				if last_space_idx > 0 {
					early_wrap := current_line[..last_space_idx + 1]
					remaining := current_line[last_space_idx + 1..]

					output_line = early_wrap
					current_line = remaining + field
					should_wrap_early = true
				}
			}

			if !should_wrap_early {
				// Can't wrap at a space, force wrap without adding a space
				output_line = current_line
				current_line = field
			}
		} else if is_line_non_empty {
			// Either added spaces or the line already ended with a space
			current_line = field
		} else {
			// Line is empty but field is too wide – place it anyway to avoid infinite loop
			current_line = field
		}

		// Append the line that we decided to output (if any)
		if output_line.len > 0 {
			lines << output_line
		}

		field_index++
	}

	// Flush the final line
	lines << current_line
	return lines
}

// wrap_simple wraps only at new lines
fn wrap_simple(s string, tab_size u32) []string {
	mut line := ''
	mut lines := []string{cap: 10}
	unsafe { lines.flags.set(.noslices) }

	for field in split_text(s, tab_size) {
		if field == '\n' {
			lines << line + '\n'
			line = ''
			continue
		}
		line += field
	}
	lines << line
	return lines
}

const r_space = ` `

// split_text splits a string by spaces with spaces as separate
// strings. Newlines are separate strings from spaces.
fn split_text(s string, tab_size u32) []string {
	state_ch := 0
	state_sp := 1

	mut state := state_ch
	mut fields := []string{cap: 100}
	unsafe { fields.flags.set(.noslices) }
	mut field := []rune{cap: 50}
	unsafe { field.flags.set(.noslices) }
	// Track visual column since last newline to expand tabs correctly
	mut col := 0
	for r in s.runes_iterator() {
		if state == state_ch {
			if r == r_space {
				if field.len > 0 {
					fields << field.string()
				}
				field.clear()
				field << r
				state = state_sp
				col += 1
			} else if r == `\n` {
				if field.len > 0 {
					fields << field.string()
				}
				fields << '\n'
				field.clear()
				col = 0
			} else if r == `\r` {
				// eat it
			} else if r == `\t` {
				if field.len > 0 {
					fields << field.string()
				}
				field.clear()
				// Expand tab according to current column position
				mut spaces := int(tab_size) - (col % int(tab_size))
				spaces = if spaces == 0 { int(tab_size) } else { spaces }
				fields << []rune{len: spaces, init: r_space}.string()
				state = state_sp
				col += spaces
			} else if utf8.is_space(r) {
				if field.len > 0 {
					fields << field.string()
				}
				field.clear()
				field << r_space
				state = state_sp
				col += 1
			} else {
				field << r
				col += 1
			}
		} else { // state == state_sp
			if r == r_space {
				field << r
				col += 1
			} else if r == `\n` {
				if field.len > 0 {
					fields << field.string()
				}
				fields << '\n'
				field.clear()
				col = 0
			} else if r == `\r` {
				// eat it
			} else if r == `\t` {
				// Expand tab from current column
				mut spaces := int(tab_size) - (col % int(tab_size))
				spaces = if spaces == 0 { int(tab_size) } else { spaces }
				field << []rune{len: spaces, init: r_space}
				col += spaces
			} else if utf8.is_space(r) {
				field << r_space
				col += 1
			} else {
				fields << field.string()
				field.clear()
				field << r
				state = state_ch
				col += 1
			}
		}
	}
	fields << field.string()
	return fields
}

// from_clipboard retrieves text content from the system clipboard and returns
// it as a string. Creates a temporary clipboard instance that is automatically
// freed after the paste operation completes.
pub fn from_clipboard() string {
	mut cb := clipboard.new()
	defer { cb.free() }
	return cb.paste()
}

// to_clipboard copies the provided string to the system clipboard if a value
// is present. Creates a temporary clipboard instance that is automatically
// freed after the copy operation completes. Returns true if the copy operation
// was successful, false if the input was none.
pub fn to_clipboard(s ?string) bool {
	if s != none {
		mut cb := clipboard.new()
		defer { cb.free() }
		return cb.copy(s)
	}
	return false
}

// count_chars returns the total number of visible characters across all
// strings in the array, used for cursor positioning in wrapped text.
fn count_chars(strs []string) int {
	mut count := 0
	for str in strs {
		count += utf8_str_visible_length(str)
	}
	return count
}
