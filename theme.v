module gui

pub const radius_none = f32(0)
pub const radius_small = f32(3)
pub const radius_medium = f32(5)
pub const radius_large = f32(7)
pub const radius_border = radius_medium + 2

pub const size_text_tiny = 10
pub const size_text_x_small = 12
pub const size_text_small = 14
pub const size_text_medium = 16
pub const size_text_large = 18
pub const size_text_x_large = 20

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
const color_select_light = rgb(159, 174, 250)
const color_border_focus_light = rgb(0, 0, 165)
const color_text_light = rgb(32, 32, 32)

const scroll_multiplier = 20
const scroll_delta_line = 1
const scroll_delta_page = 10
const size_progress_bar = 10

const text_style_dark = TextStyle{
	color:        color_text_dark
	size:         size_text_medium
	family:       font_file_regular
	line_spacing: text_line_spacing
}

const text_style_icon_dark = TextStyle{
	color:        color_text_dark
	size:         size_text_medium
	family:       font_file_icon
	line_spacing: text_line_spacing
}

// Theme describes a theme in GUI. It's large in part because GUI
// allows every view it supports to have its own styles. Normally,
// colors and fonts are shared across all views but you have the
// option to change every aspect. Themes are granular.
//
// Defining a new theme with so many styles could quickly grow
// tiresome. To assist in creating and modifying themes, GUI has a
// [theme_maker](#theme_maker) function that takes a smaller
// [ThemeCfg](#ThemeCfg) structure. `theme_maker` takes a handful
// of colors and styles and applies them to an entire theme. This
// is in fact how GUI defines its own default themes.
pub struct Theme {
pub:
	name             string = 'default' @[required]
	color_background Color  = color_background_dark // background of the window
	color_panel      Color  = color_panel_dark      // use for side panels, or groups of controls
	color_interior   Color  = color_interior_dark   // use for the interior of controls like buttons
	color_hover      Color  = color_hover_dark      // mostly mouse hovers
	color_focus      Color  = color_focus_dark      // usually keyboard focus (active/focus swapped if it looks bettter, e.g. button)
	color_active     Color  = color_active_dark     // use for clicks and other activity tasks
	color_border     Color  = color_border_dark     // borders
	color_select     Color  = color_select_dark     // links and selected
	titlebar_dark    bool

	button_style       ButtonStyle
	container_style    ContainerStyle
	date_picker_style  DatePickerStyle
	dialog_style       DialogStyle
	expand_panel_style ExpandPanelStyle
	input_style        InputStyle
	list_box_style     ListBoxStyle
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
	tooltip_style      TooltipStyle
	tree_style         TreeStyle

	// n's and b's are convenience configs for sizing
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
		family: font_file_icon
	}
	icon2 TextStyle = TextStyle{
		...text_style_dark
		size:   size_text_large
		family: font_file_icon
	}
	icon3 TextStyle = TextStyle{
		...text_style_dark
		size:   size_text_medium
		family: font_file_icon
	}
	icon4 TextStyle = TextStyle{
		...text_style_dark
		size:   size_text_small
		family: font_file_icon
	}
	icon5 TextStyle = TextStyle{
		...text_style_dark
		size:   size_text_x_small
		family: font_file_icon
	}
	icon6 TextStyle = TextStyle{
		...text_style_dark
		size:   size_text_tiny
		family: font_file_icon
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
	color_background   Color = color_background_dark
	color_panel        Color = color_panel_dark
	color_interior     Color = color_interior_dark
	color_hover        Color = color_hover_dark
	color_focus        Color = color_focus_dark
	color_active       Color = color_active_dark
	color_border       Color = color_border_dark
	color_border_focus Color = color_select_dark
	color_select       Color = color_select_dark
	titlebar_dark      bool
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
// [ThemeCfg](#ThemeCfg). Gui allows each view type (button,
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
		color_interior:   cfg.color_interior
		color_hover:      cfg.color_hover
		color_focus:      cfg.color_focus
		color_active:     cfg.color_active
		color_border:     cfg.color_border
		color_select:     cfg.color_select
		titlebar_dark:    cfg.titlebar_dark

		button_style:       ButtonStyle{
			color:              cfg.color_interior
			color_border:       cfg.color_border
			color_border_focus: cfg.color_border_focus
			color_click:        cfg.color_focus
			color_focus:        cfg.color_active
			color_hover:        cfg.color_hover
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
		date_picker_style:  DatePickerStyle{
			color:              cfg.color_interior
			color_hover:        cfg.color_hover
			color_focus:        cfg.color_focus
			color_click:        cfg.color_active
			color_border:       cfg.color_border
			color_border_focus: cfg.color_select
			color_select:       cfg.color_select
			fill:               cfg.fill
			fill_border:        cfg.fill_border
			padding:            cfg.padding
			padding_border:     cfg.padding_border
			radius:             cfg.radius
			radius_border:      cfg.radius_border
			text_style:         cfg.text_style
		}
		dialog_style:       DialogStyle{
			color:            cfg.color_panel
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
		expand_panel_style: ExpandPanelStyle{
			color:          cfg.color_panel
			color_border:   cfg.color_border
			fill:           cfg.fill
			fill_border:    cfg.fill_border
			padding:        cfg.padding_small
			padding_border: cfg.padding_border
			radius:         cfg.radius
			radius_border:  cfg.radius_border
		}
		input_style:        InputStyle{
			color:              cfg.color_interior
			color_hover:        cfg.color_hover
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
					r: cfg.text_style.color.r
					g: cfg.text_style.color.g
					b: cfg.text_style.color.b
					a: 100
				}
			}
		}
		list_box_style:     ListBoxStyle{
			color:            cfg.color_interior
			color_hover:      cfg.color_hover
			color_border:     cfg.color_border
			color_select:     cfg.color_select
			fill:             cfg.fill
			fill_border:      cfg.fill_border
			padding:          cfg.padding
			padding_border:   cfg.padding_border
			radius:           cfg.radius
			radius_border:    cfg.radius_border
			text_style:       cfg.text_style
			subheading_style: cfg.text_style
		}
		menubar_style:      MenubarStyle{
			color:               cfg.color_interior
			color_border:        cfg.color_border
			color_select:        cfg.color_select
			padding:             cfg.padding_small
			padding_border:      cfg.padding_border
			padding_submenu:     cfg.padding_small
			padding_subtitle:    padding(0, cfg.padding_small.right, 0, cfg.padding_small.left)
			radius:              cfg.radius_small
			radius_border:       cfg.radius_small
			radius_submenu:      cfg.radius_small
			radius_menu_item:    cfg.radius_small
			spacing:             cfg.spacing_medium
			text_style:          cfg.text_style
			text_style_subtitle: TextStyle{
				...cfg.text_style
				size: cfg.size_text_small
			}
		}
		progress_bar_style: ProgressBarStyle{
			color:      cfg.color_interior
			color_bar:  cfg.color_active
			fill:       true
			padding:    cfg.padding_medium
			radius:     cfg.radius
			text_style: cfg.text_style
		}
		radio_style:        RadioStyle{
			color:          cfg.color_panel
			color_hover:    cfg.color_hover
			color_focus:    cfg.color_select
			color_border:   cfg.color_border
			color_select:   cfg.text_style.color
			color_unselect: cfg.color_active
			text_style:     cfg.text_style
		}
		range_slider_style: RangeSliderStyle{
			color:          cfg.color_interior
			color_left:     cfg.color_select
			color_thumb:    cfg.color_select
			color_focus:    cfg.color_focus
			color_hover:    cfg.color_hover
			color_border:   cfg.color_border
			color_click:    cfg.color_active
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
			color_thumb:  cfg.color_active
			radius:       if cfg.radius == radius_none { radius_none } else { cfg.radius_small }
			radius_thumb: if cfg.radius == radius_none { radius_none } else { cfg.radius_small }
		}
		select_style:       SelectStyle{
			color:              cfg.color_interior
			color_border:       cfg.color_border
			color_border_focus: cfg.color_select
			color_focus:        cfg.color_focus
			color_select:       cfg.color_select
			fill:               cfg.fill
			fill_border:        cfg.fill_border
			padding:            cfg.padding_small
			padding_border:     cfg.padding_border
			radius:             cfg.radius_medium
			radius_border:      cfg.radius_medium
			text_style:         cfg.text_style
			subheading_style:   cfg.text_style
			placeholder_style:  TextStyle{
				...cfg.text_style
				color: Color{
					r: cfg.text_style.color.r
					g: cfg.text_style.color.g
					b: cfg.text_style.color.b
					a: 100
				}
			}
		}
		switch_style:       SwitchStyle{
			color:              cfg.color_panel
			color_click:        cfg.color_interior
			color_focus:        cfg.color_interior
			color_hover:        cfg.color_hover
			color_border:       cfg.color_border
			color_border_focus: cfg.color_border_focus
			color_select:       cfg.color_select
			color_unselect:     cfg.color_active
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
			color_hover:        cfg.color_hover
			color_select:       cfg.color_interior
			fill:               cfg.fill
			fill_border:        cfg.fill_border
			padding:            padding(1, 1, 1, 2)
			padding_border:     cfg.padding_border
			radius:             if cfg.radius != 0 { radius_small } else { 0 }
			radius_border:      if radius_border != 0 { radius_small } else { 0 }
			text_style:         text_style_icon_dark
			text_style_label:   cfg.text_style
		}
		tooltip_style:      TooltipStyle{
			color:              cfg.color_interior
			color_hover:        cfg.color_hover
			color_focus:        cfg.color_focus
			color_click:        cfg.color_active
			color_border:       cfg.color_border
			color_border_focus: cfg.color_border_focus
			fill:               cfg.fill
			fill_border:        cfg.fill_border
			padding:            cfg.padding_small
			padding_border:     cfg.padding_border
			radius:             cfg.radius_small
			radius_border:      cfg.radius_small
			text_style:         cfg.text_style
		}
		tree_style:         TreeStyle{
			text_style:      cfg.text_style
			text_style_icon: TextStyle{
				...cfg.text_style
				family: font_file_icon
				size:   cfg.size_text_small
			}
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
	}
	italic := TextStyle{
		...theme.text_style
		family: variants.italic
	}
	mono := TextStyle{
		...theme.text_style
		family: variants.mono
	}
	icon := TextStyle{
		...theme.text_style
		family: font_file_icon
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
			...icon
			size: theme.size_text_x_large
		}
		icon2: TextStyle{
			...icon
			size: theme.size_text_large
		}
		icon3: TextStyle{
			...icon
			size: theme.size_text_medium
		}
		icon4: TextStyle{
			...icon
			size: theme.size_text_small
		}
		icon5: TextStyle{
			...icon
			size: theme.size_text_x_small
		}
		icon6: TextStyle{
			...icon
			size: theme.size_text_tiny
		}

		menubar_style: MenubarStyle{
			...theme.menubar_style
			text_style_subtitle: TextStyle{
				...bold
				size: theme.size_text_small
			}
		}
		// sel
		select_style: SelectStyle{
			...theme.select_style
			subheading_style: TextStyle{
				...bold
			}
		}
		// listbox
		list_box_style: ListBoxStyle{
			...theme.list_box_style
			subheading_style: TextStyle{
				...bold
			}
		}
	}
}

// theme returns the current [Theme](#Theme).
pub fn theme() Theme {
	return gui_theme
}
