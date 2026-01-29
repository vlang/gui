module gui

// view_markdown.v defines the Markdown view component.
// It parses markdown source and renders it using the RTF infrastructure.
import gg
import os
import vglyph

@[minify]
struct MarkdownView implements View {
	MarkdownCfg
pub:
	rich_text RichText // Parsed at construction time
	sizing    Sizing
pub mut:
	content []View // required, not used
}

// MarkdownCfg configures a Markdown View.
@[minify]
pub struct MarkdownCfg {
pub:
	id         string
	source     string // Raw markdown text
	id_focus   u32
	mode       TextMode = .wrap
	min_width  f32
	invisible  bool
	clip       bool
	focus_skip bool
	disabled   bool
}

fn (mut md MarkdownView) generate_layout(mut window Window) Layout {
	window.stats.increment_layouts()
	window.stats.increment_rtf_views()

	// Convert RichText to vglyph.RichText
	vg_rich_text := md.rich_text.to_vglyph_rich_text()

	// Create vglyph text config
	cfg := vglyph.TextConfig{
		block: vglyph.BlockStyle{
			wrap:  if md.mode in [.wrap, .wrap_keep_spaces] { .word } else { .word }
			width: if md.mode in [.wrap, .wrap_keep_spaces] { f32(-1.0) } else { f32(-1.0) }
		}
	}

	// Layout rich text using vglyph
	layout := window.text_system.layout_rich_text(vg_rich_text, cfg) or { vglyph.Layout{} }

	shape := &Shape{
		name:          'markdown'
		shape_type:    .rtf
		id:            md.id
		id_focus:      md.id_focus
		width:         layout.width
		height:        layout.height
		clip:          md.clip
		focus_skip:    md.focus_skip
		disabled:      md.disabled
		min_width:     md.min_width
		text_mode:     md.mode
		sizing:        md.sizing
		vglyph_layout: &layout
		rich_text:     &md.rich_text
		on_click:      md_on_click
		on_mouse_move: md_mouse_move
	}

	return Layout{
		shape: shape
	}
}

// markdown creates a view from the given MarkdownCfg
pub fn markdown(cfg MarkdownCfg) View {
	if cfg.invisible {
		return invisible_container_view()
	}

	return MarkdownView{
		id:         cfg.id
		id_focus:   cfg.id_focus
		invisible:  cfg.invisible
		clip:       cfg.clip
		focus_skip: cfg.focus_skip
		disabled:   cfg.disabled
		min_width:  cfg.min_width
		mode:       cfg.mode
		source:     cfg.source
		rich_text:  markdown_to_rich_text(cfg.source)
		sizing:     if cfg.mode in [.wrap, .wrap_keep_spaces] { fill_fit } else { fit_fit }
	}
}

fn md_mouse_move(layout &Layout, mut e Event, mut w Window) {
	if !layout.shape.has_rtf_layout() {
		return
	}
	for run in layout.shape.vglyph_layout.items {
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
			if run.has_underline {
				w.set_mouse_cursor_pointing_hand()
				e.is_handled = true
				return
			}
		}
	}
}

fn md_on_click(layout &Layout, mut e Event, mut w Window) {
	if !layout.shape.has_rtf_layout() {
		return
	}
	for run in layout.shape.vglyph_layout.items {
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
			mut current_idx := u32(0)
			mut found_run_idx := -1
			for i, r in layout.shape.rich_text.runs {
				run_len := u32(r.text.len)
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
