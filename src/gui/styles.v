module gui

import gx

// gets around an chicken/egg issue with TextCfg
fn text_cfg_dark() gx.TextCfg {
	return gx.TextCfg{
		color: color_text_dark
		size:  size_text_medium
	}
}

pub struct ButtonStyle {
pub:
	color            gx.Color = color_1_dark
	color_border     gx.Color = color_border_dark
	color_click      gx.Color = color_4_dark
	color_focus      gx.Color = color_2_dark
	color_hover      gx.Color = color_3_dark
	color_click_text gx.Color = color_text_dark
	fill             bool     = true
	fill_border      bool     = true
	padding          Padding  = Padding{8, 10, 8, 10}
	padding_border   Padding  = padding_none
	radius           f32      = radius_medium
	radius_border    f32      = radius_medium
}

pub struct InputStyle {
pub:
	color          gx.Color   = color_1_dark
	color_border   gx.Color   = color_border_dark
	color_focus    gx.Color   = color_2_dark
	fill           bool       = true
	fill_border    bool       = true
	padding        Padding    = padding_small
	padding_border Padding    = padding_none
	radius         f32        = radius_medium
	radius_border  f32        = radius_medium
	text_cfg       gx.TextCfg = text_cfg_dark()
}
