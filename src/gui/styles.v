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
	color              gx.Color = color_1_dark
	color_border       gx.Color = color_border_dark
	color_border_focus gx.Color = color_link_dark
	color_click        gx.Color = color_4_dark
	color_focus        gx.Color = color_2_dark
	color_hover        gx.Color = color_3_dark
	fill               bool     = true
	fill_border        bool     = true
	padding            Padding  = Padding{8, 10, 8, 10}
	padding_border     Padding  = padding_none
	radius             f32      = radius_medium
	radius_border      f32      = radius_medium
}

pub struct ContainerStyle {
pub:
	color   gx.Color = color_transparent
	fill    bool
	padding Padding = padding_medium
	radius  f32     = radius_medium
	spacing f32     = spacing_medium
}

pub struct InputStyle {
pub:
	color              gx.Color   = color_1_dark
	color_border       gx.Color   = color_border_dark
	color_border_focus gx.Color   = color_link_dark
	color_focus        gx.Color   = color_2_dark
	fill               bool       = true
	fill_border        bool       = true
	padding            Padding    = padding_small
	padding_border     Padding    = padding_none
	radius             f32        = radius_medium
	radius_border      f32        = radius_medium
	text_cfg           gx.TextCfg = text_cfg_dark()
}

pub struct ProgressBarStyle {
pub:
	color     gx.Color = color_1_dark
	color_bar gx.Color = color_5_dark
	fill      bool     = true
	padding   Padding  = padding_medium
	radius    f32      = radius_medium
	size      f32      = size_progress_bar
}

pub struct TextStyle {
pub:
	spacing  int        = 2
	text_cfg gx.TextCfg = text_cfg_dark()
}
