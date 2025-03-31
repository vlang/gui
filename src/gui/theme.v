@[has_globals]
module gui

import gx

__global gui_theme = theme_dark

pub const color_transparent = gx.rgba(0, 0, 0, 0)
pub const padding_none = pad_4(0)
pub const radius_none = 0
pub const theme_dark = Theme{}

// Theme default is dark.
pub struct Theme {
pub mut:
	color_background   gx.Color = gx.rgb(48, 48, 48)
	color_button       gx.Color = gx.rgb(64, 64, 64)
	color_input        gx.Color = gx.rgb(64, 64, 64)
	color_link         gx.Color = gx.rgb(100, 149, 237)
	color_progress     gx.Color = gx.rgb(64, 64, 64)
	color_progress_bar gx.Color = gx.rgb(112, 112, 112)
	color_text         gx.Color = gx.rgb(225, 225, 225)

	radius_small  int = 3
	radius_medium int = 5
	radius_large  int = 7

	padding_button Padding = Padding{8, 10, 8, 10}
	padding_small  Padding = Padding{5, 5, 5, 5}
	padding_medium Padding = Padding{10, 10, 10, 10}
	padding_large  Padding = Padding{15, 15, 15, 15}
	padding_none   Padding = Padding{0, 0, 0, 0}

	spacing_small  int = 5
	spacing_medium int = 10
	spacing_large  int = 15
	spacing_text   int = 2 // additional line spacing in text.

	size_progress_bar int = 10
	size_text_small   int = 15
	size_text_medium  int = 17
	size_text_large   int = 20

	text_cfg gx.TextCfg = gx.TextCfg{
		color: gx.rgb(225, 225, 225)
		size:  17
	}
}

// theme returns the current theme.
pub fn theme() Theme {
	return gui_theme
}

// set_theme sets the current theme to the given theme.
// GUI has two builtin themes. theme_dark, theme_light
pub fn set_theme(t Theme) {
	gui_theme = t
}

// shade_color brightens or darken the color by the given percent
pub fn shade_color(color gx.Color, percent int) gx.Color {
	r := color.r * (100 + percent) / 100
	g := color.g * (100 + percent) / 100
	b := color.b * (100 + percent) / 100
	return gx.rgb(u8(r), u8(g), u8(b))
}
