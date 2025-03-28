module gui

// Padding is the gap inside the edges of a Shape. The size of a Shape always
// includes its padding. Parameter order is the same as CSS.
pub struct Padding {
pub mut:
	top    f32
	right  f32
	bottom f32
	left   f32
}

// padding is creates a padding with the given parameters.
pub fn padding(top f32, right f32, bottom f32, left f32) Padding {
	return Padding{
		top:    top
		right:  right
		bottom: bottom
		left:   left
	}
}

// pad_4 creates a padding with all 4 sides set to the `p` parameter
pub fn pad_4(p f32) Padding {
	return Padding{p, p, p, p}
}

// pad_2 creates a padding with the top and bottome set to the `tb` parameter
// and the left and right set to the `lr` parameter.
pub fn pad_2(tb f32, lr f32) Padding {
	return Padding{
		top:    tb
		right:  lr
		bottom: tb
		left:   lr
	}
}
