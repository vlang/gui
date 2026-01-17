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
import vglyph

// text_width calculates the width of a given text based on its style and window configuration,
// leveraging a caching mechanism to optimize performance.
pub fn text_width(text string, text_style TextStyle, mut window Window) f32 {
	mut cfg := text_style.to_vglyph_cfg()
	cfg.no_hit_testing = true
	return window.text_system.text_width(text, cfg) or { 0 }
}

// text_width_shape measures the visual width of the shape's lines, mirroring render rules:
// - when in password mode (and not placeholder), measure '*' repeated for visible rune count
fn text_width_shape(shape &Shape, mut window Window) f32 {
	cfg := shape.text_style.to_vglyph_cfg()

	// Fallback: If layout is not generated yet (e.g. during initial generate_layout),
	// measure the raw text. This ensures containers don't collapse to 0 width.
	// We measure "unwrapped" width here, essentially treating it as a single line.
	// The layout engine will later constrain this width if wrapping is enabled.
	if shape.text_layout.lines.len == 0 && shape.text.len > 0 {
		effective := match shape.text_is_password && !shape.text_is_placeholder {
			true { password_char.repeat(utf8_str_visible_length(shape.text)) }
			else { shape.text }
		}
		return window.text_system.text_width(effective, cfg) or { 0 }
	}

	// Optimization: If layout is present, use its cached dimensions.
	// vglyph layout provides both logical width (width) and ink width (visual_width).
	// For wrapping containers, logical width is usually constrained.
	// For "fit content", we often want the max line width.
	// vglyph.Layout.width is the width of the layout box (or max line width if not wrapping).
	// Let's trust vglyph's calculation.
	if shape.text_layout.lines.len > 0 {
		// Use visual width (ink) to match previous behavior of measuring visible pixels.
		// OR use logical width if visual width is too tight?
		// Usually visual_width matches the bounding box of the ink.
		// check if password mode needs special verification?
		// Password mode is handled by masking text BEFORE layout if we did it right,
		// but current logic masks lazily.
		// Wait, text_wrap uses shape.text (unmasked).
		// If we want accurate width for password, we must rely on the previous fallback
		// or layout the masked text.
		// Current compromise: If password, use the old measurement loop (it's rare).
		// If normal text, use cached layout width.
		if !shape.text_is_password {
			// In vglyph, `width` is the logical width (often the wrap width).
			// `visual_width` is the actual ink width.
			// We want the content width.
			// If we wrapped, `width` might be the constraint (e.g. 300px), but text might be only 50px wide.
			// We want the max line width.
			// Iterate lines is fast if we rely on line.rect?
			// vglyph.Line.rect is relative to layout.
			mut max_w := f32(0)
			for line in shape.text_layout.lines {
				max_w = f32_max(max_w, line.rect.width)
			}
			return max_w
		}
		// Fallthrough for password mode (measure '*'s)
	}

	mut max_width := f32(0)
	for line in shape.text_layout.lines {
		if line.start_index >= shape.text.len {
			continue
		}
		mut end := line.start_index + line.length
		if end > shape.text.len {
			end = shape.text.len
		}

		sub := shape.text[line.start_index..end]
		// Mirror password masking used in render so measurement matches drawing
		effective := match shape.text_is_password && !shape.text_is_placeholder {
			true { password_char.repeat(utf8_str_visible_length(sub)) }
			else { sub }
		}
		width := window.text_system.text_width(effective, cfg) or { 0 }
		max_width = f32_max(width, max_width)
	}
	return max_width
}

@[inline]
fn text_height(shape &Shape, mut window Window) f32 {
	if shape.text_layout.lines.len == 0 && shape.text.len > 0 {
		cfg := shape.text_style.to_vglyph_cfg()
		return window.text_system.font_height(cfg)
	}
	return shape.text_layout.height
}

@[inline]
fn line_height(shape &Shape, mut window Window) f32 {
	cfg := shape.text_style.to_vglyph_cfg()
	height := window.text_system.font_height(cfg)
	return height + shape.text_style.line_spacing
}

// text_wrap applies text wrapping logic to a given shape based on its text mode.
fn text_wrap(mut shape Shape, mut window Window) {
	if shape.shape_type == .text {
		// Use vglyph for layout for all text modes
		// Update config with shape-specific layout constraints.
		// Since vglyph types are immutable, we create a new instance with updates.
		// Only set width for actual wrapping modes. multiline/single_line should not wrap based on width.
		should_wrap := shape.text_mode in [.wrap, .wrap_keep_spaces]

		// Use -1.0 for unbounded width (standard Pango behavior). match default BlockStyle.
		width := match should_wrap && shape.width > 0 {
			true { shape.width - shape.padding.width() }
			else { -1.0 }
		}

		// Optimization: If layout is already generated for this width (and text hasn't changed), skip regeneration.
		// Note: We assume text and style haven't changed because Shape is usually recreated per frame if those change.
		// The main variable during layout passes is the width constraint.
		if width == shape.last_constraint_width && shape.text_layout.lines.len > 0 {
			return
		}

		mut cfg := shape.text_style.to_vglyph_cfg()
		cfg.block.width = width
		cfg.no_hit_testing = shape.id_focus == 0

		shape.text_layout = window.text_system.layout_text(shape.text, cfg) or { vglyph.Layout{} }
		shape.last_constraint_width = width

		// Calculate height based on layout
		// vglyph layout provides pixel height (visual_height or height?)
		// standard height (logical_height) includes line spacing usually.
		shape.height = match shape.text.len == 0 {
			true { line_height(shape, mut window) + shape.padding.height() }
			else { shape.text_layout.height + shape.padding.height() }
		}
		shape.max_height = shape.height
		shape.min_height = shape.height
	} else if shape.text_mode in [.wrap, .wrap_keep_spaces] && shape.shape_type == .rtf {
		width := shape.width - shape.padding.width()
		tab_size := shape.text_tab_size
		shape.text_spans = rtf_wrap_text(shape.text_spans, width, tab_size, mut window)
		shape.width, shape.height = spans_size(shape.text_spans)
	}
}

// wrap_simple wraps only at new lines
fn wrap_simple(s string, tab_size u32) []string {
	mut line := ''
	mut lines := []string{cap: 10}

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

// rune_to_byte_index converts a rune index (character count) to a byte index.
pub fn rune_to_byte_index(text string, rune_idx int) int {
	if rune_idx <= 0 {
		return 0
	}
	mut count := 0
	mut pos := 0
	for r in text.runes_iterator() {
		if count == rune_idx {
			return pos
		}
		len := if u32(r) < 0x80 {
			1
		} else if u32(r) < 0x800 {
			2
		} else if u32(r) < 0x10000 {
			3
		} else {
			4
		}
		pos += len
		count++
	}
	if count == rune_idx {
		return pos
	}
	return text.len
}

// byte_to_rune_index converts a byte index to a rune index (character count).
pub fn byte_to_rune_index(text string, byte_idx int) int {
	if byte_idx <= 0 {
		return 0
	}
	mut count := 0
	mut pos := 0
	for r in text.runes_iterator() {
		len := if u32(r) < 0x80 {
			1
		} else if u32(r) < 0x800 {
			2
		} else if u32(r) < 0x10000 {
			3
		} else {
			4
		}

		if byte_idx < pos + len {
			return count
		}

		pos += len
		count++
	}
	return count
}

const r_space = ` `

// split_text splits a string by spaces with spaces as separate
// strings. Newlines are separate strings from spaces.
fn split_text(s string, tab_size u32) []string {
	state_ch := 0
	state_sp := 1

	mut state := state_ch
	mut fields := []string{cap: 100}
	mut field := []rune{cap: 50}
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
