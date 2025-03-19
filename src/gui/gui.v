module gui

import gx

type FocusId = u32 // >0 = focusable. tabbing focus by ascending order

pub const version = '0.1.0'
pub const radius_default = 5
pub const spacing_default = 10

pub const transparent = gx.rgba(0, 0, 0, 0)
