module gui

import gx

type FocusId = u32 // >0 = focusable. tabbing focus by ascending order

pub const app_background = gx.rgb(48, 48, 48)
pub const app_title_default = 'GUI'
pub const button_background = gx.rgb(0, 0, 226)
pub const button_padding_default = padding(5, 10, 7, 10)
pub const input_color_default = gx.rgb(0x40, 0x40, 0x40)
pub const radius_default = 5
pub const spacing_default = 10
pub const text_color_default = gx.rgb(240, 240, 240)
pub const text_size_default = 18
pub const text_spacing_default = 2
pub const transparent = gx.rgba(0, 0, 0, 0)
pub const version = '0.1.0'

// shade_color brightens or darken the color by the given percent
pub fn shade_color(color gx.Color, percent int) gx.Color {
	r := color.r * (100 + percent) / 100
	g := color.g * (100 + percent) / 100
	b := color.b * (100 + percent) / 100
	return gx.rgb(u8(r), u8(g), u8(b))
}
