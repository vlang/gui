module gui

// TextSpan describes a span of text. The x,y,w,h fields are private and
// are populated by the layout engine later. TextSpans are used in Rich Text
// Format (RTF) views. RTF allows mixing different colors and fonts in the
// same text block. Hyperlinks are also supported.
pub struct TextSpan {
mut:
	x f32
	y f32
	w f32
	h f32
pub:
	id             string
	link           string
	style          TextStyle
	underline      bool
	strike_through bool
pub mut:
	text string
}

// br is a helper method to create a line break
pub fn br() TextSpan {
	return TextSpan{
		text:  '\n'
		style: gui_theme.n3
	}
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

// strike_span is a helper method to create a TextSpan with an underline
pub fn strike_span(text string, style TextStyle) TextSpan {
	return TextSpan{
		text:           text
		style:          style
		strike_through: true
	}
}

// hyperlink is a helper method to create a clickable hyperlink.
pub fn hyperlink(text string, link string, style TextStyle) TextSpan {
	return TextSpan{
		text:      text
		link:      link
		underline: true
		style:     TextStyle{
			...style
			color: gui_theme.color_select
		}
	}
}
