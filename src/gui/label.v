module gui

struct Label {
pub:
	id      string
	padding Padding
	sizing  Sizing
	text    string
}

pub struct LabelConfig {
pub:
	id      string
	padding Padding
	sizing  Sizing
	text    string
}

pub fn label(c LabelConfig) &UI_Tree {
	return &Text{
		id:      c.id
		padding: c.padding
		sizing:  c.sizing
		text:    c.text
	}
}
