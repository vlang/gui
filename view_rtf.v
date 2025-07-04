module gui

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
pub mut:z
	content []View // required, not uused
}

pub struct RtfCfg {
	id         string
	id_focus   u32
	invisible  bool
	clip       bool
	focus_skip bool
	disabled   bool
	min_width  f32
	sizing     Sizing
	spans      []TextSpan
}

fn (rtf &RtfView) generate(mut window Window) Layout {
	if rtf.invisible {
		return Layout{}
	}

	shape := Shape{
		name:       'rtf'
		type:       .rtf
		id:         rtf.id
		id_focus:   rtf.id_focus
		cfg:        &rtf.cfg
		clip:       rtf.clip
		focus_skip: rtf.focus_skip
		disabled:   rtf.disabled
		min_width:  rtf.min_width
		sizing:     rtf.sizing
		text_spans: rtf.spans
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
		sizing:     cfg.sizing
		spans:      cfg.spans
	}
}
