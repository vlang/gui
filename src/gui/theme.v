@[has_globals]
module gui

import gx

__global gui_theme = theme_dark

pub const color_transparent = gx.rgba(0, 0, 0, 0)
pub const padding_none = pad_4(0)
pub const radius_none = 0

pub const radius_small = f32(3)
pub const radius_medium = f32(5)
pub const radius_large = f32(7)

const color_1_dark = gx.rgb(64, 64, 64)
const color_2_dark = gx.rgb(74, 74, 74)
const color_3_dark = gx.rgb(84, 84, 84)
const color_4_dark = gx.rgb(94, 94, 94)
const color_5_dark = gx.rgb(104, 104, 104)
const color_link_dark = gx.rgb(100, 149, 237)
const color_text_dark = gx.rgb(255, 255, 255)
const color_border_dark = gx.rgb(255, 255, 255)

// Theme default is dark.
pub struct Theme {
pub mut:
	color_background gx.Color = gx.rgb(48, 48, 48)

	color_button            gx.Color = color_1_dark
	color_button_border     gx.Color = color_1_dark
	color_button_click      gx.Color = color_4_dark
	color_button_focus      gx.Color = color_2_dark
	color_button_hover      gx.Color = color_3_dark
	color_button_click_text gx.Color = color_text_dark

	color_input        gx.Color = color_1_dark
	color_link         gx.Color = color_link_dark
	color_progress     gx.Color = color_1_dark
	color_progress_bar gx.Color = color_5_dark

	radius_button    f32 = radius_medium
	radius_container f32 = radius_medium
	radius_input     f32 = radius_medium
	radius_progress  f32 = radius_small
	radius_rectangle f32 = radius_medium

	padding_button        Padding = Padding{8, 10, 8, 10}
	padding_button_border Padding = Padding{0, 0, 0, 0}
	padding_small         Padding = Padding{5, 5, 5, 5}
	padding_medium        Padding = Padding{10, 10, 10, 10}
	padding_large         Padding = Padding{15, 15, 15, 15}
	padding_none          Padding = Padding{0, 0, 0, 0}

	spacing_small  int = 5
	spacing_medium int = 10
	spacing_large  int = 15
	spacing_text   int = 2 // additional line spacing in text.

	size_progress_bar int = 10
	size_text_small   int = 15
	size_text_medium  int = 17
	size_text_large   int = 20

	text_cfg gx.TextCfg = gx.TextCfg{
		color: color_text_dark
		size:  17
	}
}

pub const theme_dark = Theme{}

const color_1_light = gx.rgb(150, 150, 255)
const color_2_light = gx.rgb(140, 140, 255)
const color_3_light = gx.rgb(130, 130, 255)
const color_4_light = gx.rgb(120, 120, 255)
const color_5_light = gx.rgb(91, 91, 255)
const color_link_light = gx.rgb(100, 149, 237)
const color_text_light = gx.rgb(32, 32, 32)
const color_border_light = gx.rgb(32, 32, 32)

pub const theme_light = Theme{
	color_background:    gx.rgb(248, 248, 255)
	color_button:        color_1_light
	color_button_focus:  color_2_light
	color_button_hover:  color_3_light
	color_button_click:  color_4_light
	color_button_border: color_1_light
	color_input:         color_1_light
	color_link:          color_link_light
	color_progress:      color_5_light
	color_progress_bar:  color_1_light

	text_cfg: gx.TextCfg{
		color: color_text_light
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
