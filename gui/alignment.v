module gui

// Axis defines if a Layout arranges its child layouts
// horizontally, vertically or not at all.
pub enum Axis {
	none
	top_to_bottom
	left_to_right
}

// HorizontalAlign specifies left, center, right alignment
pub enum HorizontalAlign {
	left
	center
	right
}

// VerticalAlign specifies top, middle, bottom alignment
pub enum VerticalAlign {
	top
	middle
	bottom
}
