module gui

import gx

struct Label {
pub:
	id       string
	padding  Padding
	sizing   Sizing
	spacing  f32
	text     string
	text_cfg gx.TextCfg
	wrap     bool
}

pub struct LabelConfig {
pub:
	id       string
	padding  Padding
	sizing   Sizing
	spacing  f32
	text     string
	text_cfg gx.TextCfg = gx.TextCfg{
		color: gx.white
	}
	wrap     bool
}

pub fn label(c LabelConfig) &UI_Tree {
	return &Text{
		id:       c.id
		padding:  c.padding
		sizing:   c.sizing
		spacing:  c.spacing
		text:     c.text
		text_cfg: c.text_cfg
		wrap:     c.wrap
	}
}
