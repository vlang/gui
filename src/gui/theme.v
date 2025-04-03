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

pub const size_text_small = 15
pub const size_text_medium = 17
pub const size_text_large = 20

pub const spacing_small = 5
pub const spacing_medium = 10
pub const spacing_large = 15
pub const spacing_text = 2 // additional line height

const color_0_dark = gx.rgb(48, 48, 48)
const color_1_dark = gx.rgb(64, 64, 64)
const color_2_dark = gx.rgb(74, 74, 74)
const color_3_dark = gx.rgb(84, 84, 84)
const color_4_dark = gx.rgb(94, 94, 94)
const color_5_dark = gx.rgb(104, 104, 104)
const color_border_dark = gx.rgb(225, 225, 225)
const color_link_dark = gx.rgb(100, 149, 237)
const color_text_dark = gx.rgb(225, 225, 225)

pub struct Theme {
pub:
	name             string   = 'default'
	color_background gx.Color = color_0_dark

	button_style ButtonStyle
	input_style  InputStyle

	// temp until styling finished...
	color_link         gx.Color = color_link_dark
	color_progress     gx.Color = color_1_dark
	color_progress_bar gx.Color = color_5_dark

	radius_container f32 = radius_medium
	radius_progress  f32 = radius_small
	radius_rectangle f32 = radius_medium

	padding_small  Padding = padding_small
	padding_medium Padding = padding_medium
	padding_large  Padding = padding_large

	spacing_small  int = spacing_small
	spacing_medium int = spacing_medium
	spacing_large  int = spacing_large
	spacing_text   int = spacing_text

	size_progress_bar int = 10

	size_text_small  int = size_text_small
	size_text_medium int = size_text_medium
	size_text_large  int = size_text_large

	text_cfg gx.TextCfg = gx.TextCfg{
		color: color_text_dark
		size:  size_text_medium
	}
}

pub struct ThemeCfg {
	name           string @[required]
	color_0        gx.Color   = color_0_dark
	color_1        gx.Color   = color_1_dark
	color_2        gx.Color   = color_2_dark
	color_3        gx.Color   = color_3_dark
	color_4        gx.Color   = color_4_dark
	color_5        gx.Color   = color_5_dark
	color_border   gx.Color   = color_border_dark
	color_link     gx.Color   = color_link_dark
	color_text     gx.Color   = color_text_dark
	fill           bool       = true
	fill_border    bool       = true
	padding        Padding    = padding_medium
	padding_border Padding    = padding_none
	radius         f32        = radius_medium
	radius_border  f32        = radius_medium + 2
	text_cfg       gx.TextCfg = gx.TextCfg{
		color: color_text_dark
		size:  size_text_medium
	}
}

pub const theme_dark = theme_maker(
	name:         'dark'
	color_0:      color_0_dark
	color_1:      color_1_dark
	color_2:      color_2_dark
	color_3:      color_3_dark
	color_4:      color_4_dark
	color_5:      color_5_dark
	color_border: color_border_dark
	color_link:   color_link_dark
	text_cfg:     gx.TextCfg{
		color: color_text_dark
		size:  size_text_medium
	}
)

pub const theme_light = theme_maker(
	name:         'light'
	color_0:      gx.rgb(225, 225, 225)
	color_1:      gx.rgb(150, 150, 255)
	color_2:      gx.rgb(140, 140, 255)
	color_3:      gx.rgb(130, 130, 255)
	color_4:      gx.rgb(120, 120, 255)
	color_5:      gx.rgb(91, 91, 255)
	color_border: gx.rgb(32, 32, 32)
	color_link:   gx.rgb(100, 149, 237)
	text_cfg:     gx.TextCfg{
		color: gx.rgb(32, 32, 32)
		size:  size_text_medium
	}
)

// theme_maker sets all styles to a common set of values (ThemeCfg)
// GUI allows each view type (button, input, etc) to be styled
// independent of the other view styles. However, in practice this
// is not usually required. theme_maker makes it easier to write
// new themes without having to specify styles for every view type.
// Individual styles can be modified after using theme_maker.
pub fn theme_maker(cfg ThemeCfg) Theme {
	return Theme{
		name:             cfg.name
		color_background: cfg.color_0
		text_cfg:         cfg.text_cfg

		button_style: ButtonStyle{
			color:            cfg.color_1
			color_border:     cfg.color_border
			color_click:      cfg.color_4
			color_focus:      cfg.color_2
			color_hover:      cfg.color_3
			color_click_text: cfg.color_text
			fill:             cfg.fill
			fill_border:      cfg.fill_border
			padding:          cfg.padding
			padding_border:   cfg.padding_border
			radius:           cfg.radius
			radius_border:    cfg.radius_border
		}
		input_style:  InputStyle{
			color:          cfg.color_1
			color_border:   cfg.color_border
			color_focus:    cfg.color_2
			fill:           cfg.fill
			fill_border:    cfg.fill_border
			padding:        cfg.padding
			padding_border: cfg.padding_border
			radius:         cfg.radius
			radius_border:  cfg.radius_border
			text_cfg:       cfg.text_cfg
		}
	}
}

// theme returns the current theme.
pub fn theme() Theme {
	return gui_theme
}

// set_theme sets the current theme to the given theme.
// GUI has two builtin themes. theme_dark, theme_light
pub fn set_theme(theme Theme) {
	gui_theme = theme
}
