module gui

pub const radius_none = f32(0)
pub const radius_small = f32(3.5)
pub const radius_medium = f32(5.5)
pub const radius_large = f32(7.5)
pub const radius_border = radius_medium + 2

pub const size_text_medium = 16
pub const size_text_tiny = size_text_medium - 6
pub const size_text_x_small = size_text_medium - 4
pub const size_text_small = size_text_medium - 2
pub const size_text_large = size_text_medium + 4
pub const size_text_x_large = size_text_medium + 8

pub const spacing_small = 5
pub const spacing_medium = 10
pub const spacing_large = 15
pub const text_line_spacing = f32(0) // additional line height

pub const color_transparent = rgba(0, 0, 0, 0)

const color_background_dark = rgb(48, 48, 48)
const color_panel_dark = rgb(64, 64, 64)
const color_interior_dark = rgb(74, 74, 74)
const color_hover_dark = rgb(84, 84, 84)
const color_focus_dark = rgb(94, 94, 94)
const color_active_dark = rgb(104, 104, 104)
const color_border_dark = rgb(100, 100, 100)
const color_select_dark = rgb(65, 105, 225)
const color_text_dark = rgb(225, 225, 225)

const color_background_light = rgb(225, 225, 225)
const color_panel_light = rgb(205, 205, 215)
const color_interior_light = rgb(195, 195, 215)
const color_hover_light = rgb(185, 185, 215)
const color_focus_light = rgb(175, 175, 215)
const color_active_light = rgb(165, 165, 215)
const color_border_light = rgb(135, 135, 165)
const color_select_light = rgb(65, 105, 225)
const color_border_focus_light = rgb(0, 0, 165)
const color_text_light = rgb(32, 32, 32)

const scroll_multiplier = 20
const scroll_delta_line = 1
const scroll_delta_page = 10
const scroll_gap_edge = 3
const scroll_gap_end = 2
const size_progress_bar = 10

const size_border = f32(1.5)

const text_style_dark = TextStyle{
	color:        color_text_dark
	size:         size_text_medium
	family:       base_font_name
	line_spacing: text_line_spacing
}

const text_style_icon_dark = TextStyle{
	color:        color_text_dark
	size:         size_text_medium
	family:       base_font_name
	line_spacing: text_line_spacing
}

// Good practice to expose theme configs to users.
// Makes modifying themes less tedious
pub const theme_dark_cfg = ThemeCfg{
	name:               'dark'
	color_background:   color_background_dark
	color_panel:        color_panel_dark
	color_interior:     color_interior_dark
	color_hover:        color_hover_dark
	color_focus:        color_focus_dark
	color_active:       color_active_dark
	color_border:       color_border_dark
	color_border_focus: color_select_dark
	color_select:       color_select_dark
	titlebar_dark:      true
	text_style:         text_style_dark
}
pub const theme_dark = theme_maker(theme_dark_cfg)

pub const theme_dark_no_padding_cfg = ThemeCfg{
	...theme_dark_cfg
	name:         'dark-no-padding'
	padding:      padding_none
	border_width: 0

	radius:        radius_none
	radius_border: radius_none
}
pub const theme_dark_no_padding = theme_maker(theme_dark_no_padding_cfg)

pub const theme_dark_bordered_cfg = ThemeCfg{
	...theme_dark_cfg
	name:         'dark-bordered'
	border_width: size_border
}
pub const theme_dark_bordered = theme_maker(theme_dark_bordered_cfg)

pub const theme_light_cfg = ThemeCfg{
	name:               'light'
	color_background:   color_background_light
	color_panel:        color_panel_light
	color_interior:     color_interior_light
	color_hover:        color_hover_light
	color_focus:        color_focus_light
	color_active:       color_active_light
	color_border:       color_border_light
	color_select:       color_select_light
	color_border_focus: color_border_focus_light
	text_style:         TextStyle{
		...text_style_dark
		color: color_text_light
	}
}
pub const theme_light = theme_maker(theme_light_cfg)

pub const theme_light_no_padding_cfg = ThemeCfg{
	...theme_light_cfg
	name:         'light-no-padding'
	padding:      padding_none
	border_width: 0

	radius:        radius_none
	radius_border: radius_none
}
pub const theme_light_no_padding = theme_maker(theme_light_no_padding_cfg)

pub const theme_light_bordered_cfg = ThemeCfg{
	...theme_light_cfg
	name:         'light-bordered'
	border_width: size_border
}
pub const theme_light_bordered = theme_maker(theme_light_bordered_cfg)

pub const theme_blue_bordered_cfg = ThemeCfg{
	...theme_dark_bordered_cfg
	name:               'blue-dark-bordered'
	color_background:   color_from_string('#0c1d3a')
	color_panel:        color_from_string('#122c58')
	color_interior:     color_from_string('#193b75')
	color_hover:        color_from_string('#1f4992')
	color_active:       color_from_string('#2558b0')
	color_focus:        color_from_string('#2c67cd')
	color_border:       color_from_string('#467bd7')
	color_select:       color_from_string('#427BDD')
	color_border_focus: color_from_string('#81a5e3')
}
pub const theme_blue_bordered = theme_maker(theme_blue_bordered_cfg)
