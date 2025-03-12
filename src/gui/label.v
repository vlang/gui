module gui

import gx

struct Label {
pub:
	id       string
	padding  Padding
	spacing  f32
	text     string
	wrap     bool
	text_cfg gx.TextCfg
}

// LabelConfig configures a label control
pub struct LabelConfig {
pub:
	id       string // user defined id
	spacing  f32    // add addtional space to wrapped lines
	text     string // the text to display
	wrap     bool   // wrap lines if true
	text_cfg gx.TextCfg = gx.TextCfg{
		color: gx.white
	}
}

// label is the primary way to display text in GUI.
// It can wrap text if desired. Gui spaces wrapped lines
// by the height of the font + 2 logical units. Spacing
// can be expanded further using the spacing parameter.
pub fn label(c LabelConfig) &UI_Tree {
	return &Text{
		id:       c.id
		spacing:  c.spacing
		text:     c.text
		wrap:     c.wrap
		text_cfg: c.text_cfg
	}
}
