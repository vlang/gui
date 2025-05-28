module gui

pub const radius_none = f32(0)
pub const radius_small = f32(3)
pub const radius_medium = f32(5)
pub const radius_large = f32(7)
pub const radius_border = radius_medium + 2

pub const size_text_tiny = 11
pub const size_text_x_small = 13
pub const size_text_small = 15
pub const size_text_medium = 17
pub const size_text_large = 20
pub const size_text_x_large = 26

pub const spacing_small = 5
pub const spacing_medium = 10
pub const spacing_large = 15
pub const text_line_spacing = f32(0) // additional line height

pub const color_transparent = rgba(0, 0, 0, 0)

const color_background_dark = rgb(48, 48, 48)
const color_panel_dark = rgb(64, 64, 64)
const color_interior_dark = rgb(74, 74, 74)
const color_3_dark = rgb(84, 84, 84)
const color_4_dark = rgb(94, 94, 94)
const color_5_dark = rgb(104, 104, 104)
const color_border_dark = rgb(100, 100, 100)
const color_link_dark = cornflower_blue
const color_text_dark = rgb(225, 225, 225)

const color_background_light = rgb(225, 225, 225)
const color_panel_light = rgb(205, 205, 215)
const color_interior_light = rgb(195, 195, 215)
const color_3_light = rgb(185, 185, 215)
const color_4_light = rgb(175, 175, 215)
const color_5_light = rgb(165, 165, 215)
const color_border_light = rgb(135, 135, 165)
const color_link_light = rgb(0, 71, 171)
const color_border_focus_light = rgb(0, 0, 165)
const color_text_light = rgb(32, 32, 32)

const scroll_multiplier = 20
const scroll_delta_line = 1
const scroll_delta_page = 10
const size_progress_bar = 10

const text_style_dark = TextStyle{
	color:        color_text_dark
	size:         size_text_medium
	line_spacing: text_line_spacing
}

// Theme describes a theme in GUI. It's large in part because GUI
// allows every view it supports to have its own styles. Normally,
// colors and fonts are shared across all views but you have the
// option to change every aspect. Themes are granular.
//
// Defining a new theme with so many styles could quickly grow
// tiresome. To assist in creating and modifing themes, GUI has a
// [theme_maker](#theme_maker) function that takes a smaller
// [ThemeCfg](#ThemeCfg) structure. `theme_maker` takes a handful
// of colors and styles and applies them to an entire theme. This
// is in fact how GUI defines its own default themes.
pub struct Theme {
pub:
	name             string = 'default' @[required]
	color_background Color  = color_background_dark
	color_panel      Color  = color_panel_dark
	color_link       Color  = color_link_dark
	color_border     Color  = color_border_dark
	color_selected   Color  = color_5_dark
	color_interior   Color  = color_interior_dark
	color_3          Color  = color_3_dark
	color_4          Color  = color_4_dark
	color_5          Color  = color_5_dark

	button_style       ButtonStyle
	container_style    ContainerStyle
	dialog_style       DialogStyle
	input_style        InputStyle
	menubar_style      MenubarStyle
	progress_bar_style ProgressBarStyle
	radio_style        RadioStyle
	range_slider_style RangeSliderStyle
	rectangle_style    RectangleStyle
	scrollbar_style    ScrollbarStyle
	select_style       SelectStyle
	switch_style       SwitchStyle
	text_style         TextStyle
	text_style_bold    TextStyle
	toggle_style       ToggleStyle

	// n's and b's are convienence configs for sizing
	// similar to H1-H6 in html markup. n3 is the
	// same as normal size font used by default in
	// text views
	n1 TextStyle = TextStyle{
		...text_style_dark
		size: size_text_x_large
	}
	n2 TextStyle = TextStyle{
		...text_style_dark
		size: size_text_large
	}
	n3 TextStyle = text_style_dark
	n4 TextStyle = TextStyle{
		...text_style_dark
		size: size_text_small
	}
	n5 TextStyle = TextStyle{
		...text_style_dark
		size: size_text_x_small
	}
	n6 TextStyle = TextStyle{
		...text_style_dark
		size: size_text_tiny
	}
	// Bold
	b1 TextStyle = TextStyle{
		...text_style_dark
		size: size_text_x_large
	}
	b2 TextStyle = TextStyle{
		...text_style_dark
		size: size_text_large
	}
	b3 TextStyle = TextStyle{
		...text_style_dark
		size: size_text_medium
	}
	b4 TextStyle = TextStyle{
		...text_style_dark
		size: size_text_small
	}
	b5 TextStyle = TextStyle{
		...text_style_dark
		size: size_text_x_small
	}
	b6 TextStyle = TextStyle{
		...text_style_dark
		size: size_text_tiny
	}
	// italic
	i1 TextStyle = TextStyle{
		...text_style_dark
		size: size_text_x_large
	}
	i2 TextStyle = TextStyle{
		...text_style_dark
		size: size_text_large
	}
	i3 TextStyle = TextStyle{
		...text_style_dark
		size: size_text_medium
	}
	i4 TextStyle = TextStyle{
		...text_style_dark
		size: size_text_small
	}
	i5 TextStyle = TextStyle{
		...text_style_dark
		size: size_text_x_small
	}
	i6 TextStyle = TextStyle{
		...text_style_dark
		size: size_text_tiny
	}
	// Mono
	m1 TextStyle = TextStyle{
		...text_style_dark
		size: size_text_x_large
	}
	m2 TextStyle = TextStyle{
		...text_style_dark
		size: size_text_large
	}
	m3 TextStyle = TextStyle{
		...text_style_dark
		size: size_text_medium
	}
	m4 TextStyle = TextStyle{
		...text_style_dark
		size: size_text_small
	}
	m5 TextStyle = TextStyle{
		...text_style_dark
		size: size_text_x_small
	}
	m6 TextStyle = TextStyle{
		...text_style_dark
		size: size_text_tiny
	}
	// Icon
	icon1 TextStyle = TextStyle{
		...text_style_dark
		size:   size_text_x_large
		family: icon_font_file
	}
	icon2 TextStyle = TextStyle{
		...text_style_dark
		size:   size_text_large
		family: icon_font_file
	}
	icon3 TextStyle = TextStyle{
		...text_style_dark
		size:   size_text_medium
		family: icon_font_file
	}
	icon4 TextStyle = TextStyle{
		...text_style_dark
		size:   size_text_small
		family: icon_font_file
	}
	icon5 TextStyle = TextStyle{
		...text_style_dark
		size:   size_text_x_small
		family: icon_font_file
	}
	icon6 TextStyle = TextStyle{
		...text_style_dark
		size:   size_text_tiny
		family: icon_font_file
	}

	padding_small  Padding = padding_small
	padding_medium Padding = padding_medium
	padding_large  Padding = padding_large
	padding_border Padding = padding_none

	radius_small  f32 = radius_small
	radius_medium f32 = radius_medium
	radius_large  f32 = radius_large

	spacing_small  f32 = spacing_small
	spacing_medium f32 = spacing_medium
	spacing_large  f32 = spacing_large
	spacing_text   f32 = text_line_spacing // additional line height

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

// ThemeCfg along with [theme_maker](#theme_maker) makes the chore of
// creating new themes less tiresome. All fields have default values
// as shown so you only need to specify the ones you want to change.
pub struct ThemeCfg {
pub:
	name               string @[required]
	color_background   Color     = color_background_dark
	color_panel        Color     = color_panel_dark
	color_interior     Color     = color_interior_dark
	color_3            Color     = color_3_dark
	color_4            Color     = color_4_dark
	color_5            Color     = color_5_dark
	color_border       Color     = color_border_dark
	color_border_focus Color     = color_link_dark
	color_link         Color     = color_link_dark
	color_selected     Color     = color_5_dark
	fill               bool      = true
	fill_border        bool      = true
	padding            Padding   = padding_medium
	padding_border     Padding   = padding_none
	radius             f32       = radius_medium
	radius_border      f32       = radius_border
	text_style         TextStyle = text_style_dark

	// Usually don't change across styles
	padding_small  Padding = padding_small
	padding_medium Padding = padding_medium
	padding_large  Padding = padding_large

	radius_small  f32 = radius_small
	radius_medium f32 = radius_medium
	radius_large  f32 = radius_large

	spacing_small  f32 = spacing_small
	spacing_medium f32 = spacing_medium
	spacing_large  f32 = spacing_large
	spacing_text   f32 = text_line_spacing // additional line height

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

// Good practice to expose theme configs to users.
// Makes modifying themes less tedious
pub const theme_dark_cfg = ThemeCfg{
	name:               'dark'
	color_background:   color_background_dark
	color_panel:        color_panel_dark
	color_interior:     color_interior_dark
	color_3:            color_3_dark
	color_4:            color_4_dark
	color_5:            color_5_dark
	color_border:       color_border_dark
	color_border_focus: color_link_dark
	color_link:         color_link_dark
	color_selected:     color_5_dark
	text_style:         text_style_dark
}
pub const theme_dark = theme_maker(theme_dark_cfg)

pub const theme_dark_no_padding_cfg = ThemeCfg{
	...theme_dark_cfg
	name:           'dark-no-padding'
	padding:        padding_none
	padding_border: padding_none
	radius:         radius_none
	radius_border:  radius_none
}
pub const theme_dark_no_padding = theme_maker(theme_dark_no_padding_cfg)

pub const theme_dark_bordered_cfg = ThemeCfg{
	...theme_dark_cfg
	name:           'dark-bordered'
	padding_border: padding_one
}
pub const theme_dark_bordered = theme_maker(theme_dark_bordered_cfg)

pub const theme_light_cfg = ThemeCfg{
	name:               'light'
	color_background:   color_background_light
	color_panel:        color_panel_light
	color_interior:     color_interior_light
	color_3:            color_3_light
	color_4:            color_4_light
	color_5:            color_5_light
	color_border:       color_border_light
	color_link:         color_link_light
	color_border_focus: color_border_focus_light
	color_selected:     color_5_light
	text_style:         TextStyle{
		...text_style_dark
		color: color_text_light
	}
}
pub const theme_light = theme_maker(theme_light_cfg)

pub const theme_light_no_padding_cfg = ThemeCfg{
	...theme_light_cfg
	name:           'light-no-padding'
	padding:        padding_none
	padding_border: padding_none
	radius:         radius_none
	radius_border:  radius_none
}
pub const theme_light_no_padding = theme_maker(theme_light_no_padding_cfg)

pub const theme_light_bordered_cfg = ThemeCfg{
	...theme_light_cfg
	name:           'light-bordered'
	padding_border: padding_one
}
pub const theme_light_bordered = theme_maker(theme_light_bordered_cfg)

// theme_maker sets all styles to a common set of values using
// [ThemeCfg](#ThemeCfg). GUI allows each view type (button,
// input, etc) to be styled independent of the other view styles.
// However, in practice this is not usually required. `theme_maker`
// makes it easy to write new themes without having to specify styles
// for every view type. Individual styles can be modified after using
// theme_maker. Note: `theme_maker` containers are always transparent
// and not filled.
pub fn theme_maker(cfg &ThemeCfg) Theme {
	theme := Theme{
		name:             cfg.name
		color_background: cfg.color_background
		color_panel:      cfg.color_panel
		color_link:       cfg.color_link
		color_border:     cfg.color_border
		color_selected:   cfg.color_selected
		color_interior:   cfg.color_interior
		color_3:          cfg.color_3
		color_4:          cfg.color_4
		color_5:          cfg.color_5

		button_style:       ButtonStyle{
			color:              cfg.color_interior
			color_border:       cfg.color_border
			color_border_focus: cfg.color_border_focus
			color_click:        cfg.color_4
			color_focus:        cfg.color_5
			color_hover:        cfg.color_3
			fill:               cfg.fill
			fill_border:        cfg.fill_border
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
		dialog_style:       DialogStyle{
			color:            cfg.color_interior
			color_border:     cfg.color_border
			fill:             cfg.fill
			fill_border:      cfg.fill_border
			padding:          cfg.padding_large
			padding_border:   cfg.padding_border
			radius:           cfg.radius
			radius_border:    cfg.radius_border
			title_text_style: TextStyle{
				...cfg.text_style
				size: cfg.size_text_large
			}
			text_style:       cfg.text_style
		}
		input_style:        InputStyle{
			color:              cfg.color_panel
			color_border:       cfg.color_border
			color_border_focus: cfg.color_border_focus
			color_focus:        cfg.color_interior
			fill:               cfg.fill
			fill_border:        cfg.fill_border
			padding:            cfg.padding
			padding_border:     cfg.padding_border
			radius:             cfg.radius
			radius_border:      cfg.radius_border
			text_style:         cfg.text_style
			placeholder_style:  TextStyle{
				...cfg.text_style
				color: Color{
					r: cfg.text_style.color.a
					g: cfg.text_style.color.g
					b: cfg.text_style.color.b
					a: 100
				}
			}
		}
		menubar_style:      MenubarStyle{
			color:               cfg.color_panel
			color_border:        cfg.color_border
			color_selected:      cfg.color_selected
			padding:             cfg.padding_small
			padding_border:      cfg.padding_border
			padding_submenu:     cfg.padding_small
			padding_subtitle:    padding(0, cfg.padding_small.right, 0, cfg.padding_small.left)
			radius:              cfg.radius_small
			radius_border:       cfg.radius_small
			radius_submenu:      cfg.radius_small
			radius_menu_item:    cfg.radius_small
			spacing:             cfg.spacing_medium
			text_style:          TextStyle{
				...cfg.text_style
				size: cfg.size_text_small
			}
			text_style_subtitle: TextStyle{
				...cfg.text_style
				size: cfg.size_text_x_small
			}
		}
		progress_bar_style: ProgressBarStyle{
			color:      cfg.color_panel
			color_bar:  cfg.color_5
			fill:       true
			radius:     cfg.radius
			text_style: cfg.text_style
		}
		radio_style:        RadioStyle{
			color:            cfg.color_panel
			color_focus:      cfg.color_link
			color_border:     cfg.text_style.color
			color_selected:   cfg.text_style.color
			color_unselected: cfg.color_5
			text_style:       cfg.text_style
		}
		range_slider_style: RangeSliderStyle{
			color:          cfg.color_interior
			color_click:    cfg.color_4
			color_left:     cfg.color_link
			color_focus:    cfg.color_4
			color_hover:    cfg.color_3
			color_border:   cfg.color_5
			color_thumb:    cfg.color_link
			fill:           true
			fill_border:    true
			padding:        padding_none
			padding_border: cfg.padding_border
			radius:         cfg.radius_small
			radius_border:  cfg.radius_small
		}
		rectangle_style:    RectangleStyle{
			color:  cfg.color_border
			radius: cfg.radius
			fill:   cfg.fill
		}
		scrollbar_style:    ScrollbarStyle{
			color_thumb:  cfg.color_5
			radius:       if cfg.radius == radius_none { radius_none } else { cfg.radius_small }
			radius_thumb: if cfg.radius == radius_none { radius_none } else { cfg.radius_small }
		}
		select_style:       SelectStyle{
			color:              cfg.color_interior
			color_border:       cfg.color_border
			color_border_focus: cfg.color_link
			color_click:        cfg.color_4
			color_focus:        cfg.color_5
			color_hover:        cfg.color_3
			color_selected:     cfg.color_5
			fill:               cfg.fill
			fill_border:        cfg.fill_border
			padding:            cfg.padding_small
			padding_border:     cfg.padding_border
			radius:             cfg.radius_medium
			radius_border:      cfg.radius_medium
			subheading_style:   TextStyle{
				...cfg.text_style
				color: cfg.color_link
			}
			placeholder_style:  TextStyle{
				...cfg.text_style
				color: Color{
					r: cfg.text_style.color.a
					g: cfg.text_style.color.g
					b: cfg.text_style.color.b
					a: 100
				}
			}
		}
		switch_style:       SwitchStyle{
			color:              cfg.color_panel
			color_border:       cfg.color_border
			color_border_focus: cfg.color_border_focus
			color_click:        cfg.color_interior
			color_focus:        cfg.color_interior
			color_hover:        cfg.color_3
			color_selected:     cfg.text_style.color
			color_unselected:   cfg.color_5
			fill:               cfg.fill
			fill_border:        cfg.fill_border
			padding:            padding_three
			padding_border:     cfg.padding_border
			radius:             radius_large * 2
			radius_border:      radius_large * 2
			text_style:         cfg.text_style
		}
		text_style:         cfg.text_style
		toggle_style:       ToggleStyle{
			color:              cfg.color_panel
			color_border:       cfg.color_border
			color_border_focus: cfg.color_border_focus
			color_click:        cfg.color_interior
			color_focus:        cfg.color_interior
			color_hover:        cfg.color_3
			color_selected:     cfg.color_panel
			fill:               cfg.fill
			fill_border:        cfg.fill_border
			padding:            padding_one
			padding_border:     cfg.padding_border
			radius:             if cfg.radius != 0 { radius_small } else { 0 }
			radius_border:      if radius_border != 0 { radius_small } else { 0 }
			text_style:         TextStyle{
				...cfg.text_style
				size: cfg.size_text_small
			}
			text_style_label:   cfg.text_style
		}

		// Usually don't change
		padding_small:  cfg.padding_small
		padding_medium: cfg.padding_medium
		padding_large:  cfg.padding_large
		padding_border: cfg.padding_border

		radius_small:  cfg.radius_small
		radius_medium: cfg.radius_medium
		radius_large:  cfg.radius_large

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

	variants := font_variants(theme.text_style)
	normal := TextStyle{
		...theme.text_style
		family: variants.normal
	}
	bold := TextStyle{
		...theme.text_style
		family: variants.bold
		bold:   true
	}
	italic := TextStyle{
		...theme.text_style
		family: variants.italic
	}
	mono := TextStyle{
		...theme.text_style
		family: variants.mono
	}

	return Theme{
		...theme
		n1: TextStyle{
			...normal
			size: theme.size_text_x_large
		}
		n2: TextStyle{
			...normal
			size: theme.size_text_large
		}
		n3: theme.text_style
		n4: TextStyle{
			...normal
			size: theme.size_text_small
		}
		n5: TextStyle{
			...normal
			size: theme.size_text_x_small
		}
		n6: TextStyle{
			...normal
			size: theme.size_text_tiny
		}
		// Bold
		b1: TextStyle{
			...bold
			size: theme.size_text_x_large
		}
		b2: TextStyle{
			...bold
			size: theme.size_text_large
		}
		b3: TextStyle{
			...bold
			size: theme.size_text_medium
		}
		b4: TextStyle{
			...bold
			size: theme.size_text_small
		}
		b5: TextStyle{
			...bold
			size: theme.size_text_x_small
		}
		b6: TextStyle{
			...bold
			size: theme.size_text_tiny
		}
		// Italic
		i1: TextStyle{
			...italic
			size: theme.size_text_x_large
		}
		i2: TextStyle{
			...italic
			size: theme.size_text_large
		}
		i3: TextStyle{
			...italic
			size: theme.size_text_medium
		}
		i4: TextStyle{
			...italic
			size: theme.size_text_small
		}
		i5: TextStyle{
			...italic
			size: theme.size_text_x_small
		}
		i6: TextStyle{
			...italic
			size: theme.size_text_tiny
		}
		// Mono
		m1: TextStyle{
			...mono
			size: theme.size_text_x_large
		}
		m2: TextStyle{
			...mono
			size: theme.size_text_large
		}
		m3: TextStyle{
			...mono
			size: theme.size_text_medium
		}
		m4: TextStyle{
			...mono
			size: theme.size_text_small
		}
		m5: TextStyle{
			...mono
			size: theme.size_text_x_small
		}
		m6: TextStyle{
			...mono
			size: theme.size_text_tiny
		}
		// Icon Font
		icon1: TextStyle{
			...mono
			size:   theme.size_text_x_large
			family: icon_font_file
		}
		icon2: TextStyle{
			...mono
			size:   theme.size_text_large
			family: icon_font_file
		}
		icon3: TextStyle{
			...mono
			size:   theme.size_text_medium
			family: icon_font_file
		}
		icon4: TextStyle{
			...mono
			size:   theme.size_text_small
			family: icon_font_file
		}
		icon5: TextStyle{
			...mono
			size:   theme.size_text_x_small
			family: icon_font_file
		}
		icon6: TextStyle{
			...mono
			size:   theme.size_text_tiny
			family: icon_font_file
		}
	}
}

// theme returns the current [Theme](#Theme).
pub fn theme() Theme {
	return gui_theme
}
