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
	name:        'dark-no-padding'
	padding:     padding_none
	size_border: 0

	radius:        radius_none
	radius_border: radius_none
}
pub const theme_dark_no_padding = theme_maker(theme_dark_no_padding_cfg)

pub const theme_dark_bordered_cfg = ThemeCfg{
	...theme_dark_cfg
	name:        'dark-bordered'
	size_border: size_border
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
	name:        'light-no-padding'
	padding:     padding_none
	size_border: 0

	radius:        radius_none
	radius_border: radius_none
}
pub const theme_light_no_padding = theme_maker(theme_light_no_padding_cfg)

pub const theme_light_bordered_cfg = ThemeCfg{
	...theme_light_cfg
	name:        'light-bordered'
	size_border: size_border
}
pub const theme_light_bordered = theme_maker(theme_light_bordered_cfg)

pub const theme_blue_bordered_cfg = ThemeCfg{
	name:                     'blue-dark-bordered'
	color_background:         color_from_string('#151C30')
	color_panel:              color_from_string('#1C243F')
	color_interior:           color_from_string('#202A49')
	color_hover:              color_from_string('#243054')
	color_focus:              color_from_string('#29365E')
	color_active:             color_from_string('#2D3C68')
	color_border:             color_from_string('#364263')
	color_border_focus:       color_from_string('#617AC3')
	color_select:             color_from_string('#3E65D8')
	titlebar_dark:            true
	fill:                     true
	fill_border:              true
	text_style:               TextStyle{
		color: color_from_string('#E1E1E1')
		size:  16.0
	}
	padding:                  Padding{10.0, 10.0, 10.0, 10.0}
	padding_small:            Padding{5.0, 5.0, 5.0, 5.0}
	padding_medium:           Padding{10.0, 10.0, 10.0, 10.0}
	padding_large:            Padding{15.0, 15.0, 15.0, 15.0}
	size_border:              1.5
	radius:                   5.5
	radius_border:            7.5
	radius_small:             3.52
	radius_medium:            5.5
	radius_large:             7.48
	spacing_small:            5.0
	spacing_medium:           10.0
	spacing_large:            15.0
	spacing_text:             0.0
	size_text_tiny:           10.0
	size_text_x_small:        12.0
	size_text_small:          14.0
	size_text_medium:         16.0
	size_text_large:          20.0
	size_text_x_large:        24.0
	scroll_multiplier:        20.0
	scroll_delta_line:        1.0
	scroll_delta_page:        10.0
	scroll_gap_edge:          3.0
	scroll_gap_end:           2.0
	size_switch_width:        36.0
	size_switch_height:       22.0
	size_radio:               16.0
	size_scrollbar:           7.0
	size_scrollbar_min_thumb: 20.0
	size_progress_bar:        10.0
	size_range_slider:        7.0
	size_range_slider_thumb:  15.0
	size_splitter_handle:     9.0
	width_submenu_min:        50.0
	width_submenu_max:        200.0
}
pub const theme_blue_bordered = theme_maker(theme_blue_bordered_cfg)
