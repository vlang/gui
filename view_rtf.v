module gui

import datatypes
import os

struct RtfView implements View {
pub:
	id         string
	cfg        &RtfCfg = unsafe { nil }
	sizing     Sizing
	spans      datatypes.LinkedList[TextSpan]
	min_width  f32
	id_focus   u32
	mode       TextMode
	invisible  bool
	clip       bool
	focus_skip bool
	disabled   bool
pub mut:
	content []View // required, not used
}

// RtfCfg configures a Rich Text View (RTF). RTF's can have
// multiple type faces, and sizes in a view. Different type
// faces and sizes are specified as [TextSpan](#TextSpan)s.
// Note: TextMode.wrap and TextMode.wrap_keep_spaces are the
// same for RTF.
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

fn (rtf &RtfView) generate(mut window Window) Layout {
	if rtf.invisible {
		return get_layout()
	}

	tspans := match true {
		rtf.mode in [.wrap, .wrap_keep_spaces] { rtf.spans }
		else { rtf_simple(rtf.spans, mut window) }
	}
	width, height := spans_size(tspans)

	mut layout := get_layout()
	layout.shape.name = 'rtf'
	layout.shape.type = .rtf
	layout.shape.id = rtf.id
	layout.shape.id_focus = rtf.id_focus
	layout.shape.width = width
	layout.shape.height = height
	layout.shape.cfg = &rtf.cfg
	layout.shape.clip = rtf.clip
	layout.shape.focus_skip = rtf.focus_skip
	layout.shape.disabled = rtf.disabled
	layout.shape.min_width = rtf.min_width
	layout.shape.text_mode = rtf.mode
	layout.shape.sizing = rtf.sizing
	layout.shape.text_spans = tspans
	layout.shape.on_mouse_move_shape = rtf_mouse_move_shape
	layout.shape.on_mouse_down_shape = rtf_mouse_down_shape

	return layout
}

// rtf creates a view from the given [RtfCfg](#RtfCfg)
pub fn rtf(cfg RtfCfg) View {
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

fn rtf_mouse_move_shape(shape &Shape, mut e Event, mut w Window) {
	for span in shape.text_spans {
		if span.link.len != 0 {
			if shape.point_in_span(span, e.mouse_x, e.mouse_y) {
				w.set_mouse_cursor_pointing_hand()
				e.is_handled = true
				return
			}
		}
	}
}

fn rtf_mouse_down_shape(shape &Shape, mut e Event, mut w Window) {
	for span in shape.text_spans {
		if span.link.len != 0 {
			if shape.point_in_span(span, e.mouse_x, e.mouse_y) {
				os.open_uri(span.link) or {}
				e.is_handled = true
				return
			}
		}
	}
}

fn (shape &Shape) point_in_span(span &TextSpan, x f32, y f32) bool {
	rect := DrawClip{
		x:      shape.x + span.x
		y:      shape.y + span.y
		width:  span.w
		height: span.h
	}
	return x >= rect.x && y >= rect.y && x < (rect.x + rect.width) && y < (rect.y + rect.height)
}
