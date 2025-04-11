module gui

import gx

pub const radius_none = 0
pub const radius_small = f32(3)
pub const radius_medium = f32(5)
pub const radius_large = f32(7)

pub const size_text_tiny = 11
pub const size_text_x_small = 13
pub const size_text_small = 15
pub const size_text_medium = 17
pub const size_text_large = 20
pub const size_text_x_large = 24

pub const spacing_small = 5
pub const spacing_medium = 10
pub const spacing_large = 15
pub const spacing_text = 2 // additional line height

pub const color_transparent = gx.rgba(0, 0, 0, 0)

const color_0_dark = gx.rgb(48, 48, 48)
const color_1_dark = gx.rgb(64, 64, 64)
const color_2_dark = gx.rgb(74, 74, 74)
const color_3_dark = gx.rgb(84, 84, 84)
const color_4_dark = gx.rgb(94, 94, 94)
const color_5_dark = gx.rgb(104, 104, 104)
const color_border_dark = gx.rgb(100, 100, 100)
const color_link_dark = gx.rgb(100, 149, 237)
const color_text_dark = gx.rgb(225, 225, 225)

const scroll_multiplier = 20
const scroll_delta_line = 1
const scroll_delta_page = 10
const size_progress_bar = 10

pub struct Theme {
pub:
	name             string   = 'default' @[required]
	color_background gx.Color = color_0_dark
	color_link       gx.Color = color_link_dark
	color_0          gx.Color = color_0_dark
	color_1          gx.Color = color_1_dark
	color_2          gx.Color = color_2_dark
	color_3          gx.Color = color_3_dark
	color_4          gx.Color = color_4_dark
	color_5          gx.Color = color_5_dark

	button_style       ButtonStyle
	container_style    ContainerStyle
	input_style        InputStyle
	rectangle_style    RectangleStyle
	progress_bar_style ProgressBarStyle
	text_style         TextStyle
	h1                 gx.TextCfg = gx.TextCfg{
		color: color_text_dark
		size:  size_text_x_large
	}
	h2                 gx.TextCfg = gx.TextCfg{
		color: color_text_dark
		size:  size_text_large
	}
	h3                 gx.TextCfg = gx.TextCfg{
		color: color_text_dark
		size:  size_text_medium
	}
	h4                 gx.TextCfg = gx.TextCfg{
		color: color_text_dark
		size:  size_text_small
	}
	h5                 gx.TextCfg = gx.TextCfg{
		color: color_text_dark
		size:  size_text_x_small
	}
	h6                 gx.TextCfg = gx.TextCfg{
		color: color_text_dark
		size:  size_text_tiny
	}

	padding_small  Padding = padding_small
	padding_medium Padding = padding_medium
	padding_large  Padding = padding_large

	spacing_small  int = spacing_small
	spacing_medium int = spacing_medium
	spacing_large  int = spacing_large
	spacing_text   int = spacing_text // additional line height

	size_text_tiny    int = size_text_tiny
	size_text_x_small int = size_text_x_small
	size_text_small   int = size_text_small
	size_text_medium  int = size_text_medium
	size_text_large   int = size_text_large
	size_text_x_large int = size_text_x_large

	scroll_multiplier f32 = scroll_multiplier
	scroll_delta_line f32 = scroll_delta_line
	scroll_delta_page f32 = scroll_delta_page
}

pub struct ThemeCfg {
	name               string @[required]
	color_0            gx.Color   = color_0_dark
	color_1            gx.Color   = color_1_dark
	color_2            gx.Color   = color_2_dark
	color_3            gx.Color   = color_3_dark
	color_4            gx.Color   = color_4_dark
	color_5            gx.Color   = color_5_dark
	color_border       gx.Color   = color_border_dark
	color_border_focus gx.Color   = color_link_dark
	color_link         gx.Color   = color_link_dark
	color_text         gx.Color   = color_text_dark
	fill               bool       = true
	fill_border        bool       = true
	padding            Padding    = padding_medium
	padding_border     Padding    = padding_none
	radius             f32        = radius_medium
	radius_border      f32        = radius_medium + 2
	text_cfg           gx.TextCfg = gx.TextCfg{
		color: color_text_dark
		size:  size_text_medium
	}
	// Usually don't change across styles
	padding_small  Padding = padding_small
	padding_medium Padding = padding_medium
	padding_large  Padding = padding_large

	spacing_small  int = spacing_small
	spacing_medium int = spacing_medium
	spacing_large  int = spacing_large
	spacing_text   int = spacing_text // additional line height

	size_text_tiny    int = size_text_tiny
	size_text_x_small int = size_text_x_small
	size_text_small   int = size_text_small
	size_text_medium  int = size_text_medium
	size_text_large   int = size_text_large
	size_text_x_large int = size_text_x_large

	scroll_multiplier f32 = scroll_multiplier
	scroll_delta_line f32 = scroll_delta_line
	scroll_delta_page f32 = scroll_delta_page
}

pub const theme_dark = theme_maker(
	name:               'dark'
	color_0:            color_0_dark
	color_1:            color_1_dark
	color_2:            color_2_dark
	color_3:            color_3_dark
	color_4:            color_4_dark
	color_5:            color_5_dark
	color_border:       color_border_dark
	color_border_focus: color_link_dark
	color_link:         color_link_dark
	text_cfg:           gx.TextCfg{
		color: color_text_dark
		size:  size_text_medium
	}
)

pub const theme_light = theme_maker(
	name:               'light'
	color_0:            gx.rgb(225, 225, 225)
	color_1:            gx.rgb(150, 150, 255)
	color_2:            gx.rgb(140, 140, 255)
	color_3:            gx.rgb(130, 130, 255)
	color_4:            gx.rgb(120, 120, 255)
	color_5:            gx.rgb(91, 91, 255)
	color_border:       gx.rgb(64, 64, 64)
	color_link:         gx.rgb(0, 71, 171)
	color_border_focus: gx.rgb(0, 0, 255)
	text_cfg:           gx.TextCfg{
		color: gx.rgb(32, 32, 32)
		size:  size_text_medium
	}
)

// theme_maker sets all styles to a common set of values (ThemeCfg)
// GUI allows each view type (button, input, etc) to be styled
// independent of the other view styles. However, in practice this
// is not usually required. theme_maker makes it easy to write
// new themes without having to specify styles for every view type.
// Individual styles can be modified after using theme_maker.
// Note: `theme_maker` containers are always transparent and not
// filled.
pub fn theme_maker(cfg ThemeCfg) Theme {
	theme := Theme{
		name:             cfg.name
		color_background: cfg.color_0
		color_link:       cfg.color_link
		color_0:          cfg.color_0
		color_1:          cfg.color_1
		color_2:          cfg.color_2
		color_3:          cfg.color_3
		color_4:          cfg.color_4
		color_5:          cfg.color_5

		button_style:       ButtonStyle{
			color:              cfg.color_1
			color_border:       cfg.color_border
			color_border_focus: cfg.color_border_focus
			color_click:        cfg.color_4
			color_focus:        cfg.color_2
			color_hover:        cfg.color_3
			fill:               cfg.fill
			fill_border:        cfg.fill_border
			padding:            cfg.padding
			padding_border:     cfg.padding_border
			radius:             cfg.radius
			radius_border:      cfg.radius_border
		}
		container_style:    ContainerStyle{
			color:   color_transparent
			fill:    false
			padding: cfg.padding
			radius:  cfg.radius
			spacing: cfg.spacing_medium
		}
		input_style:        InputStyle{
			color:              cfg.color_1
			color_border:       cfg.color_border
			color_border_focus: cfg.color_border_focus
			color_focus:        cfg.color_2
			fill:               cfg.fill
			fill_border:        cfg.fill_border
			padding:            cfg.padding
			padding_border:     cfg.padding_border
			radius:             cfg.radius
			radius_border:      cfg.radius_border
			text_cfg:           cfg.text_cfg
		}
		progress_bar_style: ProgressBarStyle{
			color:     cfg.color_1
			color_bar: cfg.color_5
			fill:      true
			radius:    cfg.radius
		}
		rectangle_style:    RectangleStyle{
			color:  cfg.color_border
			radius: cfg.radius
			fill:   cfg.fill
		}
		text_style:         TextStyle{
			spacing:  2
			text_cfg: cfg.text_cfg
		}

		// Usually don't change
		padding_small:  cfg.padding_small
		padding_medium: cfg.padding_medium
		padding_large:  cfg.padding_large

		spacing_small:  cfg.spacing_small
		spacing_medium: cfg.spacing_medium
		spacing_large:  cfg.spacing_large
		spacing_text:   cfg.spacing_text

		size_text_tiny:    cfg.size_text_tiny
		size_text_x_small: cfg.size_text_x_small
		size_text_small:   cfg.size_text_small
		size_text_medium:  cfg.size_text_medium
		size_text_large:   cfg.size_text_large
		size_text_x_large: cfg.size_text_x_large

		scroll_multiplier: cfg.scroll_multiplier
		scroll_delta_line: cfg.scroll_delta_line
		scroll_delta_page: cfg.scroll_delta_page
	}

	return Theme{
		...theme
		h1: gx.TextCfg{
			...theme.h1
			color: theme.text_style.text_cfg.color
			size:  theme.size_text_x_large
		}
		h2: gx.TextCfg{
			...theme.h2
			color: theme.text_style.text_cfg.color
			size:  theme.size_text_large
		}
		h3: gx.TextCfg{
			...theme.h3
			color: theme.text_style.text_cfg.color
			size:  theme.size_text_medium
		}
		h4: gx.TextCfg{
			...theme.h4
			color: theme.text_style.text_cfg.color
			size:  theme.size_text_small
		}
		h5: gx.TextCfg{
			...theme.h5
			color: theme.text_style.text_cfg.color
			size:  theme.size_text_x_small
		}
		h6: gx.TextCfg{
			...theme.h6
			color: theme.text_style.text_cfg.color
			size:  theme.size_text_tiny
		}
	}
}

// theme returns the current theme.
pub fn theme() Theme {
	return gui_theme
}
