module gui

// TextSpan describes a span of text. The x,y,w,h fields are private and
// are populated by the layout engine later.
pub struct TextSpan {
mut:
	x f32
	y f32
	w f32
	h f32
pub:
	id        string
	style     TextStyle
	underline bool
pub mut:
	text string
}

// span is a helper method to create a TextSpan
pub fn span(text string, style TextStyle) TextSpan {
	return TextSpan{
		text:  text
		style: style
	}
}

// uspan is a helper method to create a TextSpan with an underline
pub fn uspan(text string, style TextStyle) TextSpan {
	return TextSpan{
		text:      text
		style:     style
		underline: true
	}
}

// br is a helper method to create a line break
pub fn br() TextSpan {
	return TextSpan{
		text:  '\n'
		style: gui_theme.n3
	}
}
