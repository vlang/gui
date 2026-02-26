module gui

// view_rtf.v defines the Rich Text Format (RTF) view component.
// It renders text with multiple typefaces, sizes, and styles within a single view.
// Supports text wrapping, clickable links, and custom text runs.
import gg
import math
import os
import vglyph

@[minify]
struct RtfView implements View {
	RtfCfg
pub:
	sizing Sizing
pub mut:
	content []View // required, not used
}

// RtfCfg configures a Rich Text View. RTF views support multiple typefaces
// and sizes specified as RichTextRuns.
@[minify]
pub struct RtfCfg {
pub:
	id             string
	rich_text      RichText
	min_width      f32
	id_focus       u32
	mode           TextMode
	invisible      bool
	clip           bool
	focus_skip     bool
	disabled       bool
	hanging_indent f32 // negative indent for wrapped lines (for lists)
}

fn (mut rtf RtfView) generate_layout(mut window Window) Layout {
	window.stats.increment_layouts()
	window.stats.increment_rtf_views()

	// Convert RichText to vglyph.RichText (with math inline objects)
	vg_rich_text := rtf.rich_text.to_vglyph_rich_text_with_math(&window.view_state.diagram_cache)

	// Use first run's style as base so PangoLayout gets a proper
	// font description (needed for correct emoji vertical centering).
	base_style := if vg_rich_text.runs.len > 0 {
		vg_rich_text.runs[0].style
	} else {
		vglyph.TextStyle{}
	}
	cfg := vglyph.TextConfig{
		style: base_style
		block: vglyph.BlockStyle{
			wrap:   .word
			width:  -1.0
			indent: -rtf.hanging_indent
		}
	}

	// Layout rich text using vglyph
	layout := window.text_system.layout_rich_text(vg_rich_text, cfg) or { vglyph.Layout{} }

	shape := &Shape{
		shape_type: .rtf
		id:         rtf.id
		id_focus:   rtf.id_focus
		width:      layout.width
		height:     layout.height
		clip:       rtf.clip
		focus_skip: rtf.focus_skip
		disabled:   rtf.disabled
		min_width:  rtf.min_width
		sizing:     rtf.sizing
		events:     &EventHandlers{
			on_click:      rtf_on_click
			on_mouse_move: rtf_mouse_move
		}
		tc:         &ShapeTextConfig{
			text_mode:      rtf.mode
			hanging_indent: rtf.hanging_indent
			vglyph_layout:  &layout
			rich_text:      &rtf.rich_text
		}
	}

	return Layout{
		shape: shape
	}
}

// rtf creates a view from the given RtfCfg
pub fn rtf(cfg RtfCfg) View {
	if cfg.invisible {
		return invisible_container_view()
	}

	return RtfView{
		id:             cfg.id
		id_focus:       cfg.id_focus
		invisible:      cfg.invisible
		clip:           cfg.clip
		focus_skip:     cfg.focus_skip
		disabled:       cfg.disabled
		min_width:      cfg.min_width
		mode:           cfg.mode
		rich_text:      cfg.rich_text
		hanging_indent: cfg.hanging_indent
		sizing:         if cfg.mode in [.wrap, .wrap_keep_spaces] { fill_fit } else { fit_fit }
	}
}

// rtf_hit_test checks if mouse coordinates intersect a vglyph run's bounds.
const rtf_affine_inverse_epsilon = f32(0.000001)

fn rtf_run_rect(run vglyph.Item) gg.Rect {
	return gg.Rect{
		x:      f32(run.x)
		y:      f32(run.y) - f32(run.ascent)
		width:  f32(run.width)
		height: f32(run.ascent + run.descent)
	}
}

fn rtf_uniform_transform(shape &Shape) ?vglyph.AffineTransform {
	if shape.tc == unsafe { nil } || shape.tc.rich_text == unsafe { nil } {
		return none
	}
	return shape.tc.rich_text.uniform_text_transform()
}

fn rtf_affine_inverse(transform vglyph.AffineTransform) ?vglyph.AffineTransform {
	det := transform.xx * transform.yy - transform.xy * transform.yx
	if f32(math.abs(det)) <= rtf_affine_inverse_epsilon {
		return none
	}
	inv_det := f32(1.0) / det
	xx := transform.yy * inv_det
	xy := -transform.xy * inv_det
	yx := -transform.yx * inv_det
	yy := transform.xx * inv_det
	return vglyph.AffineTransform{
		xx: xx
		xy: xy
		yx: yx
		yy: yy
		x0: -(xx * transform.x0 + xy * transform.y0)
		y0: -(yx * transform.x0 + yy * transform.y0)
	}
}

fn rtf_transform_rect(rect gg.Rect, transform vglyph.AffineTransform) gg.Rect {
	x0, y0 := transform.apply(rect.x, rect.y)
	x1, y1 := transform.apply(rect.x + rect.width, rect.y)
	x2, y2 := transform.apply(rect.x + rect.width, rect.y + rect.height)
	x3, y3 := transform.apply(rect.x, rect.y + rect.height)

	mut min_x := x0
	mut max_x := x0
	mut min_y := y0
	mut max_y := y0
	for x in [x1, x2, x3] {
		min_x = f32_min(min_x, x)
		max_x = f32_max(max_x, x)
	}
	for y in [y1, y2, y3] {
		min_y = f32_min(min_y, y)
		max_y = f32_max(max_y, y)
	}
	return gg.Rect{
		x:      min_x
		y:      min_y
		width:  max_x - min_x
		height: max_y - min_y
	}
}

fn rtf_abs_run_rect(run vglyph.Item, shape &Shape, transform ?vglyph.AffineTransform) gg.Rect {
	mut rect := rtf_run_rect(run)
	if t := transform {
		rect = rtf_transform_rect(rect, t)
	}
	return gg.Rect{
		x:      rect.x + shape.x
		y:      rect.y + shape.y
		width:  rect.width
		height: rect.height
	}
}

fn rtf_hit_test(run vglyph.Item, mouse_x f32, mouse_y f32, inverse_transform ?vglyph.AffineTransform) bool {
	mut test_x := mouse_x
	mut test_y := mouse_y
	if inverse := inverse_transform {
		test_x, test_y = inverse.apply(mouse_x, mouse_y)
	}
	run_rect := rtf_run_rect(run)
	return test_x >= run_rect.x && test_y >= run_rect.y && test_x < (run_rect.x + run_rect.width)
		&& test_y < (run_rect.y + run_rect.height)
}

// rtf_mouse_move handles mouse movement over RTF content, showing tooltips
// for abbreviations and changing cursor for links.
fn rtf_mouse_move(layout &Layout, mut e Event, mut w Window) {
	if !layout.shape.has_rtf_layout() {
		return
	}
	forward_transform := rtf_uniform_transform(layout.shape)
	inverse_transform := if t := forward_transform {
		rtf_affine_inverse(t)
	} else {
		none
	}
	// Check for links/abbreviations by finding which run the mouse is over
	for run in layout.shape.tc.vglyph_layout.items {
		if run.is_object {
			continue
		}
		if rtf_hit_test(run, e.mouse_x, e.mouse_y, inverse_transform) {
			// Find corresponding RichTextRun via character offset
			found_run := rtf_find_run_at_index(layout, run.start_index)

			// Check for tooltip (abbreviation)
			if found_run.tooltip != '' {
				abs_rect := rtf_abs_run_rect(run, layout.shape, forward_transform)
				w.set_rtf_tooltip(found_run.tooltip, abs_rect)
				e.is_handled = true
				return
			}

			// Links have underline style
			if run.has_underline {
				w.set_mouse_cursor_pointing_hand()
				e.is_handled = true
				return
			}
		}
	}
}

// rtf_find_run_at_index maps a character index to the corresponding RichTextRun.
fn rtf_find_run_at_index(layout &Layout, start_index int) RichTextRun {
	mut current_idx := u32(0)
	for r in layout.shape.tc.rich_text.runs {
		run_len := u32(r.text.len)
		if u32(start_index) >= current_idx && u32(start_index) < current_idx + run_len {
			return r
		}
		current_idx += run_len
	}
	return RichTextRun{}
}

// rtf_on_click handles clicks on RTF links, validating URLs before opening.
fn rtf_on_click(layout &Layout, mut e Event, mut w Window) {
	if !layout.shape.has_rtf_layout() {
		return
	}
	inverse_transform := if t := rtf_uniform_transform(layout.shape) {
		rtf_affine_inverse(t)
	} else {
		none
	}
	// Find the clicked run and check if it's a link
	for run in layout.shape.tc.vglyph_layout.items {
		if run.is_object {
			continue
		}
		if rtf_hit_test(run, e.mouse_x, e.mouse_y, inverse_transform) {
			// Find corresponding run in original RichText
			found_run := rtf_find_run_at_index(layout, run.start_index)
			if found_run.link != '' && is_safe_url(found_run.link) {
				if found_run.link.starts_with('#') {
					w.scroll_to_view(found_run.link[1..])
				} else {
					os.open_uri(found_run.link) or {}
				}
				e.is_handled = true
			}
			return
		}
	}
}
