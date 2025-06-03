module gui

// Axis defines if a Layout arranges its child layouts
// horizontally, vertically or not at all.
pub enum Axis {
	none
	top_to_bottom
	left_to_right
}

// HorizontalAlign specifies start, center, end alignment
pub enum HorizontalAlign {
	start
	center
	end
}

// VerticalAlign specifies top, middle, bottom alignment
pub enum VerticalAlign {
	top
	middle
	bottom
}
