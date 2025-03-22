module gui

import gx

type FocusId = u32 // >0 = focusable. tabbing focus by ascending order

pub const version = '0.1.0'
pub const radius_default = 5
pub const spacing_default = 10

pub const transparent = gx.rgba(0, 0, 0, 0)

// shade_color brightens or darken the color by the given percent
pub fn shade_color(color gx.Color, percent int) gx.Color {
	r := color.r * (100 + percent) / 100
	g := color.g * (100 + percent) / 100
	b := color.b * (100 + percent) / 100
	return gx.rgb(u8(r), u8(g), u8(b))
}
