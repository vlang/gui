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
	if window.text_system == unsafe { nil } {
		return 0
	}
	mut cfg := text_style.to_vglyph_cfg()
	cfg.no_hit_testing = true
	return window.text_system.text_width(text, cfg) or { 0 }
}

// rich_text_width calculates the width of RichText accounting for all font styles.
fn rich_text_width(rt RichText, mut window Window) f32 {
	cfg := vglyph.TextConfig{
		block: vglyph.BlockStyle{
			wrap:  .word
			width: -1.0
		}
	}
	layout := window.text_system.layout_rich_text(rt.to_vglyph_rich_text(), cfg) or { return 0 }
	return layout.width
}

// text_width_shape measures the visual width of the shape's lines, mirroring render rules:
// - when in password mode (and not placeholder), measure '*' repeated for visible rune count
fn text_width_shape(shape &Shape, mut window Window) f32 {
	cfg := shape.tc.text_style.to_vglyph_cfg()

	// Fallback: If layout is not generated yet (e.g. during initial generate_layout),
	// measure the raw text. This ensures containers don't collapse to 0 width.
	// We measure "unwrapped" width here, essentially treating it as a single line.
	// The layout engine will later constrain this width if wrapping is enabled.
	// Fallback: If layout is not generated yet (e.g. during initial generate_layout),
	// measure the raw text. This ensures containers don't collapse to 0 width.
	// We measure "unwrapped" width here, essentially treating it as a single line.
	// The layout engine will later constrain this width if wrapping is enabled.
	if !shape.has_text_layout() || (shape.has_text_layout() && shape.tc.vglyph_layout.lines.len == 0
		&& shape.tc.text.len > 0) {
		effective := match shape.tc.text_is_password && !shape.tc.text_is_placeholder {
			true { password_char.repeat(utf8_str_visible_length(shape.tc.text)) }
			else { shape.tc.text }
		}
		return window.text_system.text_width(effective, cfg) or { 0 }
	}

	// Optimization: If layout is present, use its cached dimensions.
	// vglyph layout provides both logical width (width) and ink width (visual_width).
	// For wrapping containers, logical width is usually constrained.
	// For "fit content", we often want the max line width.
	// vglyph.Layout.width is the width of the layout box (or max line width if not wrapping).
	// Let's trust vglyph's calculation.
	if shape.has_text_layout() && shape.tc.vglyph_layout.lines.len > 0 {
		// Use visual width (ink) to match previous behavior of measuring visible pixels.
		// OR use logical width if visual width is too tight?
		// Usually visual_width matches the bounding box of the ink.
		// check if password mode needs special verification?
		// Password mode is handled by masking text BEFORE layout if we did it right,
		// but current logic masks lazily.
		// Wait, text_wrap uses shape.tc.text (unmasked).
		// If we want accurate width for password, we must rely on the previous fallback
		// or layout the masked text.
		// Current compromise: If password, use the old measurement loop (it's rare).
		// If normal text, use cached layout width.
		if !shape.tc.text_is_password {
			// In vglyph, `width` is the logical width (often the wrap width).
			// `visual_width` is the actual ink width.
			// We want the content width.
			// If we wrapped, `width` might be the constraint (e.g. 300px), but text might be only 50px wide.
			// We want the max line width.
			// Iterate lines is fast if we rely on line.rect?
			// vglyph.Line.rect is relative to layout.
			mut max_w := f32(0)
			for line in shape.tc.vglyph_layout.lines {
				max_w = f32_max(max_w, line.rect.width)
			}
			return max_w
		}
		// Fallthrough for password mode (measure '*'s)
	}

	mut max_width := f32(0)
	if !shape.has_text_layout() {
		return 0
	}
	for line in shape.tc.vglyph_layout.lines {
		if line.start_index >= shape.tc.text.len {
			continue
		}
		mut end := line.start_index + line.length
		if end > shape.tc.text.len {
			end = shape.tc.text.len
		}

		sub := shape.tc.text[line.start_index..end]
		// Mirror password masking used in render so measurement matches drawing
		effective := match shape.tc.text_is_password && !shape.tc.text_is_placeholder {
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
	if (!shape.has_text_layout() || shape.tc.vglyph_layout.lines.len == 0) && shape.tc.text.len > 0 {
		cfg := shape.tc.text_style.to_vglyph_cfg()
		return window.text_system.font_height(cfg) or { 0 }
	}
	if shape.has_text_layout() {
		return shape.tc.vglyph_layout.height
	}
	return 0
}

@[inline]
fn line_height(shape &Shape, mut window Window) f32 {
	if shape.tc.cached_line_height > 0 {
		return shape.tc.cached_line_height
	}
	cfg := shape.tc.text_style.to_vglyph_cfg()
	height := window.text_system.font_height(cfg) or { 0 }
	return height + shape.tc.text_style.line_spacing
}

// text_wrap applies text wrapping logic to a given shape based on its text mode.
fn text_wrap(mut shape Shape, mut window Window) {
	if shape.shape_type == .text {
		// Use vglyph for layout for all text modes
		// Update config with shape-specific layout constraints.
		// Since vglyph types are immutable, we create a new instance with updates.
		// Only set width for actual wrapping modes. multiline/single_line should not wrap based on width.
		should_wrap := shape.tc.text_mode in [.wrap, .wrap_keep_spaces]

		// Collapse spaces must happen before skip check since render uses shape.tc.text with layout indices
		if shape.tc.text_mode == .wrap {
			shape.tc.text = collapse_spaces(shape.tc.text)
		}

		// Use -1.0 for unbounded width (standard Pango behavior). match default BlockStyle.
		width := match should_wrap && shape.width > 0 {
			true { shape.width - shape.padding.width() }
			else { -1.0 }
		}

		// Optimization: compute hash of collapsed text for dirty checking
		text_hash := shape.tc.text.hash()

		// Optimization: If layout is already generated for this width and text hasn't changed, skip.
		if width == shape.tc.last_constraint_width && text_hash == shape.tc.last_text_hash
			&& shape.has_text_layout() && shape.tc.vglyph_layout.lines.len > 0 {
			return
		}

		mut cfg := shape.tc.text_style.to_vglyph_cfg()
		cfg.block.width = width
		cfg.no_hit_testing = shape.id_focus == 0

		layout := window.text_system.layout_text(shape.tc.text, cfg) or { vglyph.Layout{} }
		shape.tc.vglyph_layout = &layout
		shape.tc.last_constraint_width = width
		shape.tc.last_text_hash = text_hash
		shape.tc.cached_line_height = 0 // Clear before recomputing
		shape.tc.cached_line_height = line_height(shape, mut window)

		// Calculate height based on layout
		// vglyph layout provides pixel height (visual_height or height?)
		// standard height (logical_height) includes line spacing usually.
		shape.height = match shape.tc.text.len == 0 {
			true { line_height(shape, mut window) + shape.padding.height() }
			else { shape.tc.vglyph_layout.height + shape.padding.height() }
		}
		shape.max_height = shape.height
		shape.min_height = shape.height
	} else if shape.shape_type == .rtf {
		// New vglyph-based RTF
		if shape.has_rtf_layout() {
			if shape.tc.text_mode in [.wrap, .wrap_keep_spaces] {
				width := shape.width - shape.padding.width()

				// Optimization: Check if width changed significantly or if we haven't constrained yet
				if width > 0 && width != shape.tc.last_constraint_width {
					// Re-layout with new width constraint, preserving hanging indent
					mut cfg := vglyph.TextConfig{
						block: vglyph.BlockStyle{
							wrap:   .word
							width:  width
							indent: -shape.tc.hanging_indent
						}
					}
					// Use stored source text
					layout := window.text_system.layout_rich_text(shape.tc.rich_text.to_vglyph_rich_text_with_math(&window.view_state.diagram_cache),
						cfg) or { vglyph.Layout{} }
					shape.tc.vglyph_layout = &layout
					shape.tc.last_constraint_width = width
					shape.width = layout.width + shape.padding.width()
					shape.height = layout.height + shape.padding.height()
				}
			}
			return
		}
		// Legacy text_spans-based RTF (deprecated) - REMOVED
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

// collapse_spaces replaces multiple whitespace characters with a single space,
// while preserving newlines.
fn collapse_spaces(text string) string {
	mut res := []rune{cap: text.len}
	mut last_was_space := false

	for r in text.runes_iterator() {
		if r == `\n` {
			res << r
			last_was_space = false
			continue
		}

		is_space := utf8.is_space(r)
		if is_space {
			if !last_was_space {
				res << ` `
				last_was_space = true
			}
		} else {
			res << r
			last_was_space = false
		}
	}
	return res.string()
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

// decode_percent_prefix decodes percent-encoded bytes in
// the first 20 chars of a string (protocol area only).
fn decode_percent_prefix(s string) string {
	limit := if s.len < 20 { s.len } else { 20 }
	mut buf := []u8{cap: limit}
	mut i := 0
	for i < limit {
		if s[i] == `%` && i + 2 < s.len {
			hi := hex_digit(s[i + 1])
			lo := hex_digit(s[i + 2])
			if hi >= 0 && lo >= 0 {
				buf << u8(hi * 16 + lo)
				i += 3
				continue
			}
		}
		buf << s[i]
		i++
	}
	// Append remainder unmodified
	if limit < s.len {
		buf << s[limit..].bytes()
	}
	return buf.bytestr()
}

// hex_digit returns 0-15 for valid hex char, -1 otherwise.
fn hex_digit(c u8) int {
	if c >= `0` && c <= `9` {
		return int(c - `0`)
	}
	if c >= `a` && c <= `f` {
		return int(c - `a`) + 10
	}
	if c >= `A` && c <= `F` {
		return int(c - `A`) + 10
	}
	return -1
}

// is_safe_url validates URL protocol to prevent XSS attacks.
// Allows: http://, https://, mailto:, and relative URLs
// (no protocol). Blocks: javascript:, vbscript:, data:,
// file:, and other unsafe protocols. Decodes
// percent-encoding in the protocol portion to prevent
// bypasses like %6Aavascript:. Uses case-insensitive
// matching to prevent bypass via capitalization.
// Design: allowlist safe schemes, then blocklist dangerous
// ones, with fallthrough allowing relative URLs. This
// tradeoff supports relative paths (common in markdown)
// while blocking known attack vectors.
fn is_safe_url(url string) bool {
	lower := decode_percent_prefix(url).to_lower().trim_space()
	if lower.len == 0 {
		return false
	}
	if lower.starts_with('http://') || lower.starts_with('https://') || lower.starts_with('mailto:') {
		return true
	}
	// Relative URLs (no protocol) are safe; block known
	// dangerous schemes
	if !lower.contains('://') && !lower.starts_with('javascript:') && !lower.starts_with('data:')
		&& !lower.starts_with('vbscript:') && !lower.starts_with('file:')
		&& !lower.starts_with('blob:') {
		return true
	}
	return false
}
