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
	id         string
	rich_text  RichText
	min_width  f32
	id_focus   u32
	mode       TextMode
	invisible  bool
	clip       bool
	focus_skip bool
	disabled   bool
}

fn (mut rtf RtfView) generate_layout(mut window Window) Layout {
	stats_increment_layouts()

	// Convert RichText to vglyph.RichText
	vg_rich_text := rtf.rich_text.to_vglyph_rich_text()

	// Create vglyph text config
	cfg := vglyph.TextConfig{
		block: vglyph.BlockStyle{
			wrap:  if rtf.mode in [.wrap, .wrap_keep_spaces] { .word } else { .word }
			width: if rtf.mode in [.wrap, .wrap_keep_spaces] { f32(-1.0) } else { f32(-1.0) }
		}
	}

	// Layout rich text using vglyph
	layout := window.text_system.layout_rich_text(vg_rich_text, cfg) or { vglyph.Layout{} }

	shape := &Shape{
		name:          'rtf'
		shape_type:    .rtf
		id:            rtf.id
		id_focus:      rtf.id_focus
		width:         layout.width
		height:        layout.height
		clip:          rtf.clip
		focus_skip:    rtf.focus_skip
		disabled:      rtf.disabled
		min_width:     rtf.min_width
		text_mode:     rtf.mode
		sizing:        rtf.sizing
		rtf_layout:    &layout
		rich_text:     rtf.rich_text
		on_click:      rtf_on_click
		on_mouse_move: rtf_mouse_move
	}

	return Layout{
		shape: shape
	}
}

// rtf creates a view from the given RtfCfg
pub fn rtf(cfg RtfCfg) View {
	stats_increment_rtf_views()

	if cfg.invisible {
		return invisible_container_view()
	}

	return RtfView{
		id:         cfg.id
		id_focus:   cfg.id_focus
		invisible:  cfg.invisible
		clip:       cfg.clip
		focus_skip: cfg.focus_skip
		disabled:   cfg.disabled
		min_width:  cfg.min_width
		mode:       cfg.mode
		rich_text:  cfg.rich_text
		sizing:     if cfg.mode in [.wrap, .wrap_keep_spaces] { fill_fit } else { fit_fit }
	}
}

fn rtf_mouse_move(layout &Layout, mut e Event, mut w Window) {
	if !layout.shape.has_rtf_layout() {
		return
	}
	// Check for links by finding which run the mouse is over
	for run in layout.shape.rtf_layout.items {
		if run.is_object {
			continue
		}
		run_rect := gg.Rect{
			x:      f32(run.x)
			y:      f32(run.y) - f32(run.ascent)
			width:  f32(run.width)
			height: f32(run.ascent + run.descent)
		}
		if e.mouse_x >= run_rect.x && e.mouse_y >= run_rect.y
			&& e.mouse_x < (run_rect.x + run_rect.width)
			&& e.mouse_y < (run_rect.y + run_rect.height) {
			// Links have underline style
			if run.has_underline {
				w.set_mouse_cursor_pointing_hand()
				e.is_handled = true
				return
			}
		}
	}
}

fn rtf_on_click(layout &Layout, mut e Event, mut w Window) {
	if !layout.shape.has_rtf_layout() {
		return
	}
	// Find the clicked run and check if it's a link
	for run in layout.shape.rtf_layout.items {
		if run.is_object {
			continue
		}
		run_rect := gg.Rect{
			x:      f32(run.x)
			y:      f32(run.y) - f32(run.ascent)
			width:  f32(run.width)
			height: f32(run.ascent + run.descent)
		}
		if e.mouse_x >= run_rect.x && e.mouse_y >= run_rect.y
			&& e.mouse_x < (run_rect.x + run_rect.width)
			&& e.mouse_y < (run_rect.y + run_rect.height) {
			// Find corresponding run in original RichText
			// We map via offsets because vglyph text runs might be split or reordered (bidi),
			// and text content might be empty for some glyph runs.
			mut current_idx := u32(0)
			mut found_run_idx := -1
			for i, r in layout.shape.rich_text.runs {
				run_len := u32(r.text.len)
				// Check if the clicked run's start index falls within this RichText run
				if u32(run.start_index) >= current_idx
					&& u32(run.start_index) < current_idx + run_len {
					found_run_idx = i
					break
				}
				current_idx += run_len
			}

			if found_run_idx >= 0 {
				found_run := layout.shape.rich_text.runs[found_run_idx]
				if found_run.link != '' {
					os.open_uri(found_run.link) or {}
					e.is_handled = true
				}
			}
			return
		}
	}
}
