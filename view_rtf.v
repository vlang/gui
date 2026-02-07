module gui

// view_rtf.v defines the Rich Text Format (RTF) view component.
// It renders text with multiple typefaces, sizes, and styles within a single view.
// Supports text wrapping, clickable links, and custom text runs.
import gg
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

	// Create vglyph text config
	// Negative indent creates hanging indent (wrapped lines indented)
	cfg := vglyph.TextConfig{
		block: vglyph.BlockStyle{
			wrap:   .word
			width:  -1.0
			indent: -rtf.hanging_indent
		}
	}

	// Layout rich text using vglyph
	layout := window.text_system.layout_rich_text(vg_rich_text, cfg) or { vglyph.Layout{} }

	shape := &Shape{
		name:           'rtf'
		shape_type:     .rtf
		id:             rtf.id
		id_focus:       rtf.id_focus
		width:          layout.width
		height:         layout.height
		clip:           rtf.clip
		focus_skip:     rtf.focus_skip
		disabled:       rtf.disabled
		min_width:      rtf.min_width
		text_mode:      rtf.mode
		sizing:         rtf.sizing
		hanging_indent: rtf.hanging_indent
		vglyph_layout:  &layout
		rich_text:      &rtf.rich_text
		on_click:       rtf_on_click
		on_mouse_move:  rtf_mouse_move
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
fn rtf_hit_test(run vglyph.Item, mouse_x f32, mouse_y f32) bool {
	run_rect := gg.Rect{
		x:      f32(run.x)
		y:      f32(run.y) - f32(run.ascent)
		width:  f32(run.width)
		height: f32(run.ascent + run.descent)
	}
	return mouse_x >= run_rect.x && mouse_y >= run_rect.y && mouse_x < (run_rect.x + run_rect.width)
		&& mouse_y < (run_rect.y + run_rect.height)
}

// rtf_mouse_move handles mouse movement over RTF content, showing tooltips
// for abbreviations and changing cursor for links.
fn rtf_mouse_move(layout &Layout, mut e Event, mut w Window) {
	if !layout.shape.has_rtf_layout() {
		return
	}
	// Check for links/abbreviations by finding which run the mouse is over
	for run in layout.shape.vglyph_layout.items {
		if run.is_object {
			continue
		}
		if rtf_hit_test(run, e.mouse_x, e.mouse_y) {
			// Find corresponding RichTextRun via character offset
			found_run := rtf_find_run_at_index(layout, run.start_index)

			// Check for tooltip (abbreviation)
			if found_run.tooltip != '' {
				// Convert to window coordinates (run position is relative to layout)
				abs_rect := gg.Rect{
					x:      f32(run.x) + layout.shape.x
					y:      f32(run.y) - f32(run.ascent) + layout.shape.y
					width:  f32(run.width)
					height: f32(run.ascent + run.descent)
				}
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
	for r in layout.shape.rich_text.runs {
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
	// Find the clicked run and check if it's a link
	for run in layout.shape.vglyph_layout.items {
		if run.is_object {
			continue
		}
		if rtf_hit_test(run, e.mouse_x, e.mouse_y) {
			// Find corresponding run in original RichText
			found_run := rtf_find_run_at_index(layout, run.start_index)
			if found_run.link != '' && is_safe_url(found_run.link) {
				os.open_uri(found_run.link) or {}
				e.is_handled = true
			}
			return
		}
	}
}
