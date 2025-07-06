module gui

@[heap]
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
	sizing     Sizing
	spans      []TextSpan
pub mut:
	content []View // required, not uused
}

// RtfCfg configures a Rich Text View (RTF). RTF's can have
// multiple type faces, and sizes in a view. Different type
// faces and sizes are specified as [TextSpan](#TextSpan)s.
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

	tspans := rtf_simple(rtf.spans, mut window)
	width, height := spans_size(tspans)

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

// rtf creates a view specified byte the given [RtfCfg](#RtfCfg)
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
