module gui

import gx

pub struct ButtonStyle {
pub:
	color_button            gx.Color = color_1_dark
	color_button_border     gx.Color = color_border_dark
	color_button_click      gx.Color = color_4_dark
	color_button_focus      gx.Color = color_2_dark
	color_button_hover      gx.Color = color_3_dark
	color_button_click_text gx.Color = color_text_dark
	fill_button             bool     = true
	fill_button_border      bool     = true
	radius_button           f32      = radius_medium
	padding_button          Padding  = Padding{8, 10, 8, 10}
	padding_button_border   Padding  = Padding{0, 0, 0, 0}
}
