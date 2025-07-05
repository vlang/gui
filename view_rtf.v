module gui

import arrays

pub struct RtfView implements View {
pub:
	id         string
	id_focus   u32
	invisible  bool
	cfg        &RtfCfg = unsafe { nil }
	clip       bool
	focus_skip bool
	disabled   bool
	min_width  f32
	sizing     Sizing
	spans      []TextSpan
pub mut:
	content []View // required, not uused
}

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

	tspans := rtf_wrap_simple(rtf.spans, 0, mut window)
	width := arrays.sum(tspans.map(it.w)) or { 0 }
	height := arrays.max(tspans.map(it.h)) or { 0 }

	shape := Shape{
		name:       'rtf'
		type:       .rtf
		id:         rtf.id
		id_focus:   rtf.id_focus
		width:      width
		height:     height
		cfg:        &rtf.cfg
		clip:       rtf.clip
		focus_skip: rtf.focus_skip
		disabled:   rtf.disabled
		min_width:  rtf.min_width
		sizing:     rtf.sizing
		text_spans: tspans
	}

	return Layout{
		shape: shape
	}
}

pub fn rtf(cfg RtfCfg) RtfView {
	return RtfView{
		id:         cfg.id
		id_focus:   cfg.id_focus
		invisible:  cfg.invisible
		clip:       cfg.clip
		focus_skip: cfg.focus_skip
		disabled:   cfg.disabled
		min_width:  cfg.min_width
		sizing:     if cfg.mode in [.wrap, .wrap_keep_spaces] { fill_fit } else { fit_fit }
		spans:      cfg.spans
	}
}

fn rtf_wrap_simple(spans []TextSpan, tab_size u32, mut window Window) []TextSpan {
	mut x := f32(0)
	mut y := f32(0)
	mut tspans := []TextSpan{}
	for span in spans {
		width := get_text_width(span.text, span.style, mut window)
		tspans << TextSpan{
			...span
			x: x
			y: y
			w: width
			h: span.style.size
		}
		x += width
	}
	return tspans
}
