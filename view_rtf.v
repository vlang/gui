module gui

import datatypes
import os

struct RtfView implements View {
pub:
	id         string
	id_focus   u32
	invisible  bool
	cfg        &RtfCfg = unsafe { nil }
	clip       bool
	focus_skip bool
	disabled   bool
	min_width  f32
	mode       TextMode
	sizing     Sizing
	spans      datatypes.LinkedList[TextSpan]
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
	id_focus   u32
	invisible  bool
	clip       bool
	focus_skip bool
	disabled   bool
	min_width  f32
	mode       TextMode
	spans      []TextSpan
}

fn (rtf &RtfView) generate(mut window Window) Layout {
	if rtf.invisible {
		return Layout{}
	}

	tspans := match true {
		rtf.mode in [.wrap, .wrap_keep_spaces] { rtf.spans }
		else { rtf_simple(rtf.spans, mut window) }
	}
	width, height := spans_size(tspans)

	shape := Shape{
		name:                'rtf'
		type:                .rtf
		id:                  rtf.id
		id_focus:            rtf.id_focus
		width:               width
		height:              height
		cfg:                 &rtf.cfg
		clip:                rtf.clip
		focus_skip:          rtf.focus_skip
		disabled:            rtf.disabled
		min_width:           rtf.min_width
		text_mode:           rtf.mode
		sizing:              rtf.sizing
		text_spans:          tspans
		on_mouse_move_shape: rtf_mouse_move_shape
		on_mouse_down_shape: rtf_mouse_down_shape
	}

	return Layout{
		shape: shape
	}
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
