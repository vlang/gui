module gui

import gx

pub const transparent = gx.rgba(0, 0, 0, 0)
pub const black = gx.black
pub const blue = gx.blue
pub const cyan = gx.cyan
pub const dark_blue = gx.dark_blue
pub const dark_gray = gx.dark_gray
pub const dark_green = gx.dark_green
pub const dark_red = gx.dark_red
pub const gray = gx.gray
pub const green = gx.green
pub const indigo = gx.indigo
pub const light_blue = gx.light_blue
pub const light_gray = gx.light_gray
pub const light_green = gx.light_green
pub const light_red = gx.light_red
pub const magenta = gx.magenta
pub const orange = gx.orange
pub const pink = gx.pink
pub const purple = gx.purple
pub const red = gx.red
pub const violet = gx.violet
pub const white = gx.white
pub const yellow = gx.yellow

pub fn rgb(r u8, g u8, b u8) gx.Color {
	return rgba(r, g, b, 0xff)
}

pub fn rgba(r u8, g u8, b u8, a u8) gx.Color {
	return gx.rgba(r, g, b, a)
}
