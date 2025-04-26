module gui

import gx

pub struct ButtonStyle {
pub:
	color              Color   = color_1_dark
	color_border       Color   = color_border_dark
	color_border_focus Color   = color_link_dark
	color_click        Color   = color_4_dark
	color_focus        Color   = color_2_dark
	color_hover        Color   = color_3_dark
	fill               bool    = true
	fill_border        bool    = true
	padding            Padding = Padding{8, 10, 8, 10}
	padding_border     Padding = padding_none
	radius             f32     = radius_medium
	radius_border      f32     = radius_medium
}

pub struct ContainerStyle {
pub:
	color   Color = color_transparent
	fill    bool
	padding Padding = padding_medium
	radius  f32     = radius_medium
	spacing f32     = spacing_medium
}

pub struct DialogStyle {
pub:
	color            Color           = color_1_dark
	color_border     Color           = color_border_dark
	fill             bool            = true
	fill_border      bool            = true
	padding          Padding         = padding_large
	padding_border   Padding         = padding_none
	radius           f32             = radius_medium
	radius_border    f32             = radius_medium
	align_buttons    HorizontalAlign = .center
	title_text_style TextStyle       = TextStyle{
		...text_style_dark
		size: size_text_large
	}
	text_style       TextStyle = text_style_dark
}

pub struct InputStyle {
pub:
	color              Color     = color_1_dark
	color_border       Color     = color_border_dark
	color_border_focus Color     = color_link_dark
	color_focus        Color     = color_2_dark
	fill               bool      = true
	fill_border        bool      = true
	padding            Padding   = padding_small
	padding_border     Padding   = padding_none
	radius             f32       = radius_medium
	radius_border      f32       = radius_medium
	text_style         TextStyle = text_style_dark
	placeholder_style  TextStyle = TextStyle{
		...text_style_dark
		color: Color{
			r: text_style_dark.color.a
			g: text_style_dark.color.g
			b: text_style_dark.color.b
			a: 100
		}
	}
}

pub struct ProgressBarStyle {
pub:
	color     Color   = color_1_dark
	color_bar Color   = color_5_dark
	fill      bool    = true
	padding   Padding = padding_medium
	radius    f32     = radius_medium
	size      f32     = size_progress_bar
}

pub struct RectangleStyle {
pub:
	color  Color = color_border_dark
	radius f32   = radius_medium
	fill   bool
}

pub struct TextStyle {
pub:
	color        Color
	size         int
	family       string
	line_spacing f32
}

fn (tc TextStyle) to_text_cfg() gx.TextCfg {
	return gx.TextCfg{
		color:  tc.color.to_gx_color()
		size:   tc.size
		family: tc.family
		bold:   true
	}
}
