module gui

import gx

struct Label {
pub:
	id       string
	padding  Padding
	spacing  f32
	text     string
	text_cfg gx.TextCfg
	wrap     bool
}

pub struct LabelConfig {
pub:
	id       string
	padding  Padding
	spacing  f32
	text     string
	wrap     bool
	text_cfg gx.TextCfg = gx.TextCfg{
		color: gx.white
	}
}

pub fn label(c LabelConfig) &UI_Tree {
	return &Text{
		id:       c.id
		padding:  c.padding
		spacing:  c.spacing
		text:     c.text
		text_cfg: c.text_cfg
		wrap:     c.wrap
	}
}
