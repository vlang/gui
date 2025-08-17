// Starting the filename with _ causes it to be
// parsed first. V is working on this issue but
// it may be sometime before it is resolved.
//
@[has_globals]
module gui

import math

__global gui_theme = theme_dark_no_padding
__global gui_tooltip = TooltipState{}
__global cosf_values = [32]f32{}
__global sinf_values = [32]f32{}

pub const version = '0.1.0'
pub const app_title = 'GUI'

struct TooltipState {
mut:
	id     u32
	bounds DrawClip
}

fn init() {
	// cosf_values, sinf_values are used in render2.v for drawing rounded
	// corners on rectangles. Yes, there are several magic numbers here
	// and the drawing routines assume these arrays are initialized and
	// are the correct size.
	for idx in 0 .. 31 {
		rad := f32(math.radians(idx * 3))
		cosf_values[idx] = math.cosf(rad)
		sinf_values[idx] = math.sinf(rad)
	}
}
