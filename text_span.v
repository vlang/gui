module gui

pub struct TextSpan {
	x f32
	y f32
	w f32
	h f32
pub:
	id    string
	text  string
	style TextStyle
}

// span is a helper method to create a TextSpan
pub fn span(text string, style TextStyle) TextSpan {
	return TextSpan{
		text:  text
		style: style
	}
}
