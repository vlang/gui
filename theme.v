module gui

// theme_maker sets all styles to a common set of values using
// [ThemeCfg](#ThemeCfg). v-gui allows each view type (button,
// input, etc) to be styled independent of the other view styles.
// However, in practice this is not usually required. `theme_maker`
// makes it easy to write new themes without having to specify styles
// for every view type. Individual styles can be modified after using
// theme_maker. Note: `theme_maker` containers are always transparent
// and not filled.
pub fn theme_maker(cfg &ThemeCfg) Theme {
	theme := Theme{
		cfg:              *cfg
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
			icon_style:         TextStyle{
				...cfg.text_style
				family: icon_font_name
				size:   cfg.size_text_medium
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
			color_left:     cfg.color_active
			color_thumb:    cfg.color_active
			color_focus:    cfg.color_border_focus
			color_hover:    cfg.color_hover
			color_border:   cfg.color_border
			color_click:    cfg.color_select
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
			gap_edge:     cfg.scroll_gap_edge
			gap_end:      cfg.scroll_gap_end
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
				family: icon_font_name
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
		family: icon_font_name
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
			size: theme.size_text_x_large + 1
		}
		m2: TextStyle{
			...mono
			size: theme.size_text_large + 1
		}
		m3: TextStyle{
			...mono
			size: theme.size_text_medium + 1
		}
		m4: TextStyle{
			...mono
			size: theme.size_text_small + 1
		}
		m5: TextStyle{
			...mono
			size: theme.size_text_x_small + 1
		}
		m6: TextStyle{
			...mono
			size: theme.size_text_tiny + 1
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

// adjust_font_size creates a new theme with font sizes adjusted by the specified delta value.
// All text sizes in the theme (tiny through x-large) are increased or decreased by delta.
// The function validates that the adjusted sizes stay within the provided min_size and max_size bounds.
//
// Parameters:
//   delta    - Amount to increase (positive) or decrease (negative) all font sizes by
//   min_size - Minimum allowed font size (must be > 0)
//   max_size - Maximum allowed font size (must be >= min_size)
//
// Returns:
//   - On success: A new Theme with all font sizes adjusted by delta
//   - On error: If min_size < 1 or if any adjusted size would be outside the min/max bounds
//
// Example:
//   new_theme := theme.adjust_font_size(2, 8, 32)! // Increase all sizes by 2
pub fn (theme Theme) adjust_font_size(delta f32, min_size f32, max_size f32) !Theme {
	if min_size < 1 {
		return error('min_size must be > 0')
	}
	cfg := theme.cfg
	new_font_size := cfg.text_style.size + delta
	if new_font_size < min_size || new_font_size > max_size {
		return error('new_font_size out of range')
	}
	theme_cfg := ThemeCfg{
		...cfg
		text_style:        TextStyle{
			...cfg.text_style
			size: new_font_size
		}
		size_text_tiny:    cfg.size_text_tiny + delta
		size_text_x_small: cfg.size_text_x_small + delta
		size_text_small:   cfg.size_text_small + delta
		size_text_medium:  cfg.size_text_medium + delta
		size_text_large:   cfg.size_text_large + delta
		size_text_x_large: cfg.size_text_x_large + delta
	}
	new_theme := theme_maker(theme_cfg)
	return new_theme
}

// theme returns the current [Theme](#Theme).
pub fn theme() Theme {
	return gui_theme
}
