module svg

import encoding.html
import math
import os

// Security limits for SVG parsing to prevent DoS attacks.
// These values are conservative but allow rendering of complex real-world SVGs.
const default_icon_size = 24
const max_group_depth = 32 // Prevents stack overflow from deep nesting. SVG spec has no limit; 32 allows 2³² elements via exponential nesting while staying within stack bounds.
const max_elements = 100000 // Prevents DoS from element count. Most icons have <10 elements; complex SVGs like tiger.svg have ~240.
const max_path_segments = 100000 // Prevents DoS from path complexity. Typical paths have <50 segments.
const max_viewbox_dim = 10000 // Prevents extreme allocations from huge viewBox dimensions.
const max_attr_len = 1048576 // 1MB attribute limit prevents excessive string allocations.
const max_coordinate = 1000000.0 // Prevents overflow in polygon operations and OOM from extreme coordinate values.

// ParseState tracks mutable state during SVG parsing.
struct ParseState {
mut:
	elem_count int
	texts      []SvgText
	text_paths []SvgTextPath
}

// GroupStyle holds inherited style properties for groups.
struct GroupStyle {
	transform      [6]f32
	fill           string
	stroke         string
	stroke_width   string
	stroke_cap     string
	stroke_join    string
	clip_path_id   string
	filter_id      string
	font_family    string
	font_size      string
	font_weight    string
	font_style     string
	text_anchor    string
	opacity        f32 = 1.0
	fill_opacity   f32 = 1.0
	stroke_opacity f32 = 1.0
}

// parse_svg_dimensions extracts only width/height from SVG without
// full parse+tessellate. Used to avoid double load when display
// dimensions are specified.
pub fn parse_svg_dimensions(content string) (f32, f32) {
	if vb := find_attr(content, 'viewBox') {
		nums := parse_number_list(vb)
		if nums.len >= 4 {
			return clamp_viewbox_dim(nums[2]), clamp_viewbox_dim(nums[3])
		}
	}
	w := if wa := find_attr(content, 'width') {
		clamp_viewbox_dim(parse_length(wa))
	} else {
		f32(default_icon_size)
	}
	h := if ha := find_attr(content, 'height') {
		clamp_viewbox_dim(parse_length(ha))
	} else {
		f32(default_icon_size)
	}
	return w, h
}

// parse_svg parses an SVG string and returns a VectorGraphic.
pub fn parse_svg(content string) !VectorGraphic {
	mut vg := VectorGraphic{
		width:  default_icon_size
		height: default_icon_size
	}

	// Parse viewBox
	if vb := find_attr(content, 'viewBox') {
		nums := parse_number_list(vb)
		if nums.len >= 4 {
			vg.view_box_x = nums[0]
			vg.view_box_y = nums[1]
			vg.width = clamp_viewbox_dim(nums[2])
			vg.height = clamp_viewbox_dim(nums[3])
		}
	} else {
		// Try width/height attributes
		if w := find_attr(content, 'width') {
			vg.width = clamp_viewbox_dim(parse_length(w))
		}
		if h := find_attr(content, 'height') {
			vg.height = clamp_viewbox_dim(parse_length(h))
		}
	}

	// Pre-pass: extract <defs> blocks
	vg.clip_paths = parse_defs_clip_paths(content)
	vg.gradients = parse_defs_gradients(content)
	vg.filters = parse_defs_filters(content)
	vg.defs_paths = parse_defs_paths(content)

	// Parse with group support — apply viewBox offset as translation
	mut vb_transform := identity_transform
	if vg.view_box_x != 0 || vg.view_box_y != 0 {
		vb_transform = [f32(1), 0, 0, 1, -vg.view_box_x, -vg.view_box_y]!
	}
	default_style := GroupStyle{
		transform: vb_transform
	}
	mut state := ParseState{}
	all_paths := parse_svg_content(content, default_style, 0, mut state)

	// Separate filtered paths from main paths
	if vg.filters.len > 0 {
		mut filtered := map[string][]VectorPath{}
		mut filtered_texts := map[string][]SvgText{}
		for p in all_paths {
			if p.filter_id.len > 0 && p.filter_id in vg.filters {
				filtered[p.filter_id] << p
			} else {
				vg.paths << p
			}
		}
		// Partition texts by filter_id
		for t in state.texts {
			if t.filter_id.len > 0 && t.filter_id in vg.filters {
				filtered_texts[t.filter_id] << t
			} else {
				vg.texts << t
			}
		}
		// Partition text_paths by filter_id
		mut filtered_text_paths := map[string][]SvgTextPath{}
		for tp in state.text_paths {
			if tp.filter_id.len > 0 && tp.filter_id in vg.filters {
				filtered_text_paths[tp.filter_id] << tp
			} else {
				vg.text_paths << tp
			}
		}
		for fid, fpaths in filtered {
			vg.filtered_groups << SvgFilteredGroup{
				filter_id:  fid
				paths:      fpaths
				texts:      filtered_texts[fid]
				text_paths: filtered_text_paths[fid]
			}
		}
	} else {
		vg.paths = all_paths
		vg.texts = state.texts
		vg.text_paths = state.text_paths
	}

	return vg
}

// parse_svg_content parses SVG content recursively, handling groups.
// depth limits recursion; state.elem_count limits total elements parsed.
fn parse_svg_content(content string, inherited GroupStyle, depth int, mut state ParseState) []VectorPath {
	mut paths := []VectorPath{}
	mut pos := 0

	// Reject excessive nesting depth
	if depth > max_group_depth {
		return paths
	}

	for pos < content.len {
		// Stop if element limit reached
		if state.elem_count >= max_elements {
			break
		}
		// Find next element
		start := find_index(content, '<', pos) or { break }

		// Skip comments and declarations
		if start + 3 < content.len {
			if content[start..start + 4] == '<!--' {
				// Skip comment
				end := find_index(content, '-->', start) or { break }
				pos = end + 3
				continue
			}
			if content[start + 1] == `!` || content[start + 1] == `?` {
				end := find_index(content, '>', start) or { break }
				pos = end + 1
				continue
			}
		}

		// Check for closing tag
		if start + 1 < content.len && content[start + 1] == `/` {
			end := find_index(content, '>', start) or { break }
			pos = end + 1
			continue
		}

		// Extract tag name
		tag_end := find_tag_name_end(content, start + 1)
		if tag_end <= start + 1 {
			pos = start + 1
			continue
		}
		tag_name := content[start + 1..tag_end]

		// Find element end
		elem_end := find_index(content, '>', start) or { break }
		elem := content[start..elem_end + 1]
		is_self_closing := elem_end > 0 && content[elem_end - 1] == `/`

		// Handle different elements
		// Skip <defs> blocks (already parsed in pre-pass)
		if tag_name == 'defs' {
			if is_self_closing {
				pos = elem_end + 1
				continue
			}
			defs_end := find_closing_tag(content, 'defs', elem_end + 1)
			close_end := find_index(content, '>', defs_end) or { break }
			pos = close_end + 1
			continue
		}

		if tag_name == 'g' || tag_name == 'a' {
			// Parse group (treat <a> as a container like <g>)
			group_style := merge_group_style(elem, inherited)
			state.elem_count++

			if is_self_closing {
				pos = elem_end + 1
				continue
			}

			// Find closing tag
			group_content_start := elem_end + 1
			group_end := find_closing_tag(content, tag_name, group_content_start)
			if group_end > group_content_start {
				group_content := content[group_content_start..group_end]
				paths << parse_svg_content(group_content, group_style, depth + 1, mut
					state)
			}
			close_end := find_index(content, '>', group_end) or { break }
			pos = close_end + 1
		} else if tag_name == 'path' {
			state.elem_count++
			if p := parse_path_with_style(elem, inherited) {
				paths << p
			}
			pos = elem_end + 1
		} else if tag_name == 'rect' {
			state.elem_count++
			if p := parse_rect_with_style(elem, inherited) {
				paths << p
			}
			pos = elem_end + 1
		} else if tag_name == 'circle' {
			state.elem_count++
			if p := parse_circle_with_style(elem, inherited) {
				paths << p
			}
			pos = elem_end + 1
		} else if tag_name == 'ellipse' {
			state.elem_count++
			if p := parse_ellipse_with_style(elem, inherited) {
				paths << p
			}
			pos = elem_end + 1
		} else if tag_name == 'polygon' {
			state.elem_count++
			if p := parse_polygon_with_style(elem, inherited, true) {
				paths << p
			}
			pos = elem_end + 1
		} else if tag_name == 'polyline' {
			state.elem_count++
			if p := parse_polygon_with_style(elem, inherited, false) {
				paths << p
			}
			pos = elem_end + 1
		} else if tag_name == 'line' {
			state.elem_count++
			if p := parse_line_with_style(elem, inherited) {
				paths << p
			}
			pos = elem_end + 1
		} else if tag_name == 'text' {
			state.elem_count++
			if !is_self_closing {
				text_content_start := elem_end + 1
				text_end := find_closing_tag(content, 'text', text_content_start)
				if text_end > text_content_start {
					text_body := content[text_content_start..text_end]
					parse_text_element(elem, text_body, inherited, mut state)
				}
				close := find_index(content, '>', text_end) or { break }
				pos = close + 1
			} else {
				pos = elem_end + 1
			}
			continue
		} else {
			pos = elem_end + 1
		}
	}

	return paths
}

// extract_transform_scale returns the average scale factor from an
// affine transform matrix [a,b,c,d,e,f].
fn extract_transform_scale(m [6]f32) f32 {
	sx := math.sqrtf(m[0] * m[0] + m[1] * m[1])
	sy := math.sqrtf(m[2] * m[2] + m[3] * m[3])
	return (sx + sy) / 2.0
}

// extract_plain_text returns text content before the first child element.
fn extract_plain_text(body string) string {
	lt := find_index(body, '<', 0) or { return html.unescape(body.trim_space(), all: true) }
	return html.unescape(body[..lt].trim_space(), all: true)
}

// parse_svg_file loads and parses an SVG file.
pub fn parse_svg_file(path string) !VectorGraphic {
	content := os.read_file(path) or { return error('Failed to read SVG file: ${path}') }
	return parse_svg(content)
}
