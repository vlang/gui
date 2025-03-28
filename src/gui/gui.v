module gui

import gx

type FocusId = u32 // >0 = focusable. tabbing focus by ascending order

pub const version = '0.1.0'
pub const app_title = 'GUI'

pub const color_background = gx.rgb(48, 48, 48)
pub const color_button = gx.rgb(54, 64, 64)
pub const color_input = gx.rgb(64, 64, 64)
pub const color_link = gx.rgb(100, 149, 237)
pub const color_text = gx.rgb(225, 225, 225)
pub const color_transparent = gx.rgba(0, 0, 0, 0)

pub const radius_small = 3
pub const radius_medium = 5
pub const radius_large = 7
pub const radius_none = 0

pub const padding_button = pad_2(8, 10)
pub const padding_small = pad_4(5)
pub const padding_medium = pad_4(10)
pub const padding_large = pad_4(15)
pub const padding_none = pad_4(0)

pub const spacing_small = 5
pub const spacing_medium = 10
pub const spacing_large = 15
pub const spacing_text = 2 // additional line spacing in text.

pub const size_text_small = 15
pub const size_text_medium = 17
pub const size_text_large = 20

pub const text_cfg = gx.TextCfg{
	color: color_text
	size:  size_text_medium
}

// shade_color brightens or darken the color by the given percent
pub fn shade_color(color gx.Color, percent int) gx.Color {
	r := color.r * (100 + percent) / 100
	g := color.g * (100 + percent) / 100
	b := color.b * (100 + percent) / 100
	return gx.rgb(u8(r), u8(g), u8(b))
}
