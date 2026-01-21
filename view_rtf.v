module gui

// view_rtf.v defines the Rich Text Format (RTF) view component.
// It allows rendering text with multiple typefaces, sizes, and styles within a single view.
// It supports text wrapping, clickable links, and custom text spans.
//
import datatypes
import os

@[minify]
struct RtfView implements View {
	RtfCfg
pub:
	sizing Sizing
pub mut:
	spans   datatypes.LinkedList[TextSpan]
	content []View // required, not used
}

// RtfCfg configures a Rich Text View (RTF). RTF's can have
// multiple type faces, and sizes in a view. Different type
// faces and sizes are specified as [TextSpan](#TextSpan)s.
// Note: TextMode.wrap and TextMode.wrap_keep_spaces are the
// same for RTF.
@[minify]
pub struct RtfCfg {
pub:
	id         string
	spans      []TextSpan
	min_width  f32
	id_focus   u32
	mode       TextMode
	invisible  bool
	clip       bool
	focus_skip bool
	disabled   bool
}

fn (mut rtf RtfView) generate_layout(mut window Window) Layout {
	$if !prod {
		gui_stats.increment_layouts()
	}

	tspans := match true {
		rtf.mode in [.wrap, .wrap_keep_spaces] { rtf.spans }
		else { rtf_simple_wrap(rtf.spans, mut window) }
	}
	width, height := spans_size(tspans)

	mut shape := window.alloc_shape()
	shape.name = 'rtf'
	shape.shape_type = .rtf
	shape.id = rtf.id
	shape.id_focus = rtf.id_focus
	shape.width = width
	shape.height = height
	shape.clip = rtf.clip
	shape.focus_skip = rtf.focus_skip
	shape.disabled = rtf.disabled
	shape.min_width = rtf.min_width
	shape.text_mode = rtf.mode
	shape.sizing = rtf.sizing
	shape.text_spans = &tspans
	shape.on_click = rtf_on_click
	shape.on_mouse_move = rtf_mouse_move

	return Layout{
		shape: shape
	}
}

// rtf creates a view from the given [RtfCfg](#RtfCfg)
pub fn rtf(cfg RtfCfg) View {
	$if !prod {
		gui_stats.increment_rtf_views()
	}

	if cfg.invisible {
		return invisible_container_view()
	}

	mut ll := datatypes.LinkedList[TextSpan]{}
	ll.push_many(cfg.spans)

	return RtfView{
		id:         cfg.id
		id_focus:   cfg.id_focus
		invisible:  cfg.invisible
		clip:       cfg.clip
		focus_skip: cfg.focus_skip
		disabled:   cfg.disabled
		min_width:  cfg.min_width
		mode:       cfg.mode
		sizing:     if cfg.mode in [.wrap, .wrap_keep_spaces] { fill_fit } else { fit_fit }
		spans:      ll
	}
}

fn rtf_mouse_move(layout &Layout, mut e Event, mut w Window) {
	for span in layout.shape.text_spans {
		if span.link.len != 0 {
			if point_in_text_span(span, e.mouse_x, e.mouse_y) {
				w.set_mouse_cursor_pointing_hand()
				e.is_handled = true
				return
			}
		}
	}
}

fn rtf_on_click(layout &Layout, mut e Event, mut w Window) {
	for span in layout.shape.text_spans {
		if span.link.len != 0 {
			if point_in_text_span(span, e.mouse_x, e.mouse_y) {
				os.open_uri(span.link) or {}
				e.is_handled = true
				return
			}
		}
	}
}

fn point_in_text_span(span &TextSpan, x f32, y f32) bool {
	return x >= span.x && y >= span.y && x < (span.x + span.w) && y < (span.y + span.h)
}
