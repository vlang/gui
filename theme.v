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
	// Helper to reduce boilerplate
	make_style := fn (base TextStyle, size f32) TextStyle {
		return TextStyle{
			...base
			size: size
		}
	}

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

		color_picker_style:    ColorPickerStyle{
			color:              cfg.color_interior
			color_hover:        cfg.color_hover
			color_border:       cfg.color_border
			color_border_focus: cfg.color_border_focus
			padding:            cfg.padding_small
			size_border:        cfg.size_border
			radius:             cfg.radius
			text_style:         cfg.text_style
		}
		breadcrumb_style:      BreadcrumbStyle{
			color_crumb_hover:    cfg.color_hover
			color_crumb_click:    cfg.color_active
			color_content:        cfg.color_panel
			color_content_border: cfg.color_border
			padding_trail:        cfg.padding_small
			padding_content:      cfg.padding
			radius:               cfg.radius
			radius_crumb:         cfg.radius_small
			radius_content:       cfg.radius
			spacing:              cfg.spacing_small
			spacing_trail:        cfg.spacing_small
			size_content_border:  cfg.size_border
			text_style:           cfg.text_style
			text_style_selected:  TextStyle{
				...cfg.text_style
				typeface: .bold
			}
			text_style_disabled:  TextStyle{
				...cfg.text_style
				color: Color{
					r: cfg.text_style.color.r
					g: cfg.text_style.color.g
					b: cfg.text_style.color.b
					a: 130
				}
			}
			text_style_separator: TextStyle{
				...cfg.text_style
				color: Color{
					r: cfg.text_style.color.r
					g: cfg.text_style.color.g
					b: cfg.text_style.color.b
					a: 160
				}
			}
			text_style_icon:      TextStyle{
				...cfg.text_style
				family: icon_font_name
				size:   cfg.size_text_medium
			}
		}
		button_style:          ButtonStyle{
			color:              cfg.color_interior
			color_border:       cfg.color_border
			color_border_focus: cfg.color_border_focus
			color_click:        cfg.color_focus
			color_focus:        cfg.color_active
			color_hover:        cfg.color_hover
			size_border:        cfg.size_border
			radius:             cfg.radius
			radius_border:      cfg.radius_border
		}
		container_style:       ContainerStyle{
			color:       color_transparent
			padding:     cfg.padding
			radius:      cfg.radius
			spacing:     cfg.spacing_medium
			size_border: cfg.size_border
		}
		date_picker_style:     DatePickerStyle{
			color:              cfg.color_interior
			color_hover:        cfg.color_hover
			color_focus:        cfg.color_focus
			color_click:        cfg.color_active
			color_border:       cfg.color_border
			color_border_focus: cfg.color_select
			color_select:       cfg.color_select
			padding:            cfg.padding
			size_border:        cfg.size_border
			radius:             cfg.radius
			radius_border:      cfg.radius_border
			text_style:         cfg.text_style
		}
		data_grid_style:       DataGridStyle{
			color_background:    cfg.color_interior
			color_header:        cfg.color_panel
			color_header_hover:  cfg.color_hover
			color_filter:        cfg.color_interior
			color_quick_filter:  cfg.color_panel
			color_row_hover:     cfg.color_hover
			color_row_alt:       color_transparent
			color_row_selected:  cfg.color_select
			color_border:        cfg.color_border
			color_resize_handle: cfg.color_border
			color_resize_active: cfg.color_border_focus
			padding_cell:        padding_two_five
			padding_header:      padding_two_five
			padding_filter:      padding_none
			size_border:         cfg.size_border
			radius:              cfg.radius_small
			text_style:          cfg.text_style
			text_style_header:   TextStyle{
				...cfg.text_style
				typeface: .bold
			}
			text_style_filter:   cfg.text_style
		}
		dialog_style:          DialogStyle{
			color:              cfg.color_panel
			color_border:       cfg.color_border
			color_border_focus: cfg.color_border_focus
			padding:            cfg.padding_large
			size_border:        cfg.size_border

			radius:           cfg.radius
			radius_border:    cfg.radius_border
			title_text_style: TextStyle{
				...cfg.text_style
				size: cfg.size_text_large
			}
			text_style:       cfg.text_style
		}
		expand_panel_style:    ExpandPanelStyle{
			color:              cfg.color_panel
			color_hover:        cfg.color_hover
			color_focus:        cfg.color_focus
			color_border:       cfg.color_border
			color_border_focus: cfg.color_border_focus
			padding:            cfg.padding_small
			size_border:        cfg.size_border

			radius:        cfg.radius
			radius_border: cfg.radius_border
		}
		input_style:           InputStyle{
			color:              cfg.color_interior
			color_hover:        cfg.color_hover
			color_focus:        cfg.color_interior
			color_click:        cfg.color_active
			color_border:       cfg.color_border
			color_border_focus: cfg.color_border_focus
			padding:            cfg.padding
			size_border:        cfg.size_border
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
		list_box_style:        ListBoxStyle{
			color:              cfg.color_interior
			color_hover:        cfg.color_hover
			color_focus:        cfg.color_focus
			color_border:       cfg.color_border
			color_border_focus: cfg.color_border_focus
			color_select:       cfg.color_select
			padding:            cfg.padding
			size_border:        cfg.size_border

			radius:           cfg.radius
			radius_border:    cfg.radius_border
			text_style:       cfg.text_style
			subheading_style: cfg.text_style
		}
		menubar_style:         MenubarStyle{
			width_submenu_min:  cfg.width_submenu_min
			width_submenu_max:  cfg.width_submenu_max
			color:              cfg.color_interior
			color_hover:        cfg.color_hover
			color_focus:        cfg.color_focus
			color_border:       cfg.color_border
			color_border_focus: cfg.color_border_focus
			color_select:       cfg.color_select
			padding:            cfg.padding_small
			size_border:        cfg.size_border

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
		progress_bar_style:    ProgressBarStyle{
			size:         cfg.size_progress_bar
			color:        cfg.color_interior
			color_bar:    cfg.color_active
			color_border: cfg.color_border
			padding:      cfg.padding_medium
			size_border:  cfg.size_border
			radius:       cfg.radius
			text_style:   cfg.text_style
		}
		radio_style:           RadioStyle{
			size:               cfg.size_radio
			color:              cfg.color_panel
			color_hover:        cfg.color_hover
			color_focus:        cfg.color_select
			color_border:       cfg.color_border
			color_border_focus: cfg.color_border_focus
			color_select:       cfg.color_select
			color_unselect:     cfg.color_active
			text_style:         cfg.text_style
			size_border:        cfg.size_border
		}
		range_slider_style:    RangeSliderStyle{
			size:               cfg.size_range_slider
			thumb_size:         cfg.size_range_slider_thumb
			color:              cfg.color_interior
			color_left:         cfg.color_active
			color_thumb:        cfg.color_active
			color_focus:        cfg.color_border_focus
			color_hover:        cfg.color_hover
			color_border:       cfg.color_border
			color_border_focus: cfg.color_border_focus
			color_click:        cfg.color_select
			padding:            padding_none
			size_border:        cfg.size_border

			radius:        cfg.radius_small
			radius_border: cfg.radius_small
		}
		rectangle_style:       RectangleStyle{
			color_border: cfg.color_border
			radius:       cfg.radius
			size_border:  cfg.size_border
		}
		scrollbar_style:       ScrollbarStyle{
			size:           cfg.size_scrollbar
			min_thumb_size: cfg.size_scrollbar_min_thumb
			color_thumb:    cfg.color_active
			radius:         if cfg.radius == radius_none { radius_none } else { cfg.radius_small }
			radius_thumb:   if cfg.radius == radius_none { radius_none } else { cfg.radius_small }
			gap_edge:       cfg.scroll_gap_edge
			gap_end:        cfg.scroll_gap_end
		}
		select_style:          SelectStyle{
			color:              cfg.color_interior
			color_hover:        cfg.color_hover
			color_focus:        cfg.color_focus
			color_click:        cfg.color_active
			color_border:       cfg.color_border
			color_border_focus: cfg.color_border_focus
			color_select:       cfg.color_select
			padding:            cfg.padding_small
			size_border:        cfg.size_border
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
		splitter_style:        SplitterStyle{
			handle_size:         cfg.size_splitter_handle
			drag_step:           0.02
			drag_step_large:     0.10
			color_handle:        cfg.color_interior
			color_handle_hover:  cfg.color_hover
			color_handle_active: cfg.color_active
			color_handle_border: cfg.color_border
			color_grip:          cfg.color_select
			color_button:        cfg.color_interior
			color_button_hover:  cfg.color_hover
			color_button_active: cfg.color_active
			color_button_icon:   cfg.text_style.color
			size_border:         cfg.size_border
			radius:              cfg.radius_small
			radius_border:       cfg.radius_small
		}
		switch_style:          SwitchStyle{
			size_width:         cfg.size_switch_width
			size_height:        cfg.size_switch_height
			color:              cfg.color_panel
			color_click:        cfg.color_interior
			color_focus:        cfg.color_interior
			color_hover:        cfg.color_hover
			color_border:       cfg.color_border
			color_border_focus: cfg.color_border_focus
			color_select:       cfg.color_select
			color_unselect:     cfg.color_active
			padding:            padding_three
			size_border:        cfg.size_border
			radius:             radius_large * 2
			radius_border:      radius_large * 2
			text_style:         cfg.text_style
		}
		tab_style:             TabStyle{
			color:                  cfg.color_panel
			color_border:           cfg.color_border
			color_header:           color_transparent
			color_header_border:    color_transparent
			color_content:          cfg.color_panel
			color_content_border:   cfg.color_border
			color_tab:              cfg.color_interior
			color_tab_hover:        cfg.color_hover
			color_tab_focus:        cfg.color_focus
			color_tab_click:        cfg.color_active
			color_tab_selected:     cfg.color_select
			color_tab_disabled:     cfg.color_panel
			color_tab_border:       cfg.color_border
			color_tab_border_focus: cfg.color_border_focus
			padding:                padding_none
			padding_header:         padding_none
			padding_content:        cfg.padding
			padding_tab:            cfg.padding_small
			size_border:            cfg.size_border
			size_header_border:     0
			size_content_border:    cfg.size_border
			size_tab_border:        cfg.size_border
			radius:                 cfg.radius
			radius_header:          cfg.radius_small
			radius_content:         cfg.radius
			radius_tab:             cfg.radius_small
			radius_tab_border:      cfg.radius_small
			spacing:                cfg.spacing_small
			spacing_header:         cfg.spacing_small
			text_style:             cfg.text_style
			text_style_selected:    TextStyle{
				...cfg.text_style
				typeface: .bold
			}
			text_style_disabled:    TextStyle{
				...cfg.text_style
				color: Color{
					r: cfg.text_style.color.r
					g: cfg.text_style.color.g
					b: cfg.text_style.color.b
					a: 130
				}
			}
		}
		text_style:            cfg.text_style
		toggle_style:          ToggleStyle{
			color:              cfg.color_panel
			color_border:       cfg.color_border
			color_border_focus: cfg.color_border_focus
			color_click:        cfg.color_interior
			color_focus:        cfg.color_interior
			color_hover:        cfg.color_hover
			color_select:       cfg.color_interior
			padding:            padding(1, 1, 1, 2)
			size_border:        cfg.size_border
			radius:             cfg.radius
			radius_border:      cfg.radius_border
			text_style:         cfg.text_style
			text_style_label:   cfg.text_style
		}
		tooltip_style:         TooltipStyle{
			color:              cfg.color_interior
			color_hover:        cfg.color_hover
			color_focus:        cfg.color_focus
			color_click:        cfg.color_active
			color_border:       cfg.color_border
			color_border_focus: cfg.color_border_focus
			padding:            cfg.padding_small
			size_border:        cfg.size_border
			radius:             cfg.radius_small
			radius_border:      cfg.radius_small
			text_style:         cfg.text_style
		}
		tree_style:            TreeStyle{
			color:              color_transparent
			color_hover:        cfg.color_hover
			color_focus:        cfg.color_focus
			color_border:       color_transparent
			color_border_focus: cfg.color_border_focus
			padding:            padding_none
			size_border:        cfg.size_border
			radius:             cfg.radius
			text_style:         cfg.text_style
			text_style_icon:    TextStyle{
				...cfg.text_style
				family: icon_font_name
				size:   cfg.size_text_small
			}
		}
		combobox_style:        ComboboxStyle{
			color:              cfg.color_interior
			color_hover:        cfg.color_hover
			color_focus:        cfg.color_interior
			color_border:       cfg.color_border
			color_border_focus: cfg.color_border_focus
			color_highlight:    cfg.color_select
			padding:            cfg.padding_small
			size_border:        cfg.size_border
			radius:             cfg.radius
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
		command_palette_style: CommandPaletteStyle{
			color:           cfg.color_panel
			color_border:    cfg.color_border
			color_highlight: cfg.color_select
			size_border:     cfg.size_border
			radius:          cfg.radius
			text_style:      cfg.text_style
			detail_style:    TextStyle{
				...cfg.text_style
				color: Color{
					r: cfg.text_style.color.r
					g: cfg.text_style.color.g
					b: cfg.text_style.color.b
					a: 140
				}
			}
		}

		// Usually don't change
		padding_small:  cfg.padding_small
		padding_medium: cfg.padding_medium
		padding_large:  cfg.padding_large
		size_border:    cfg.size_border

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
	bold_italic := TextStyle{
		...theme.text_style
		typeface: .bold_italic
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
		n1: make_style(normal, theme.size_text_x_large)
		n2: make_style(normal, theme.size_text_large)
		n3: theme.text_style
		n4: make_style(normal, theme.size_text_small)
		n5: make_style(normal, theme.size_text_x_small)
		n6: make_style(normal, theme.size_text_tiny)
		// Bold
		b1: make_style(bold, theme.size_text_x_large)
		b2: make_style(bold, theme.size_text_large)
		b3: make_style(bold, theme.size_text_medium)
		b4: make_style(bold, theme.size_text_small)
		b5: make_style(bold, theme.size_text_x_small)
		b6: make_style(bold, theme.size_text_tiny)
		// Italic
		i1: make_style(italic, theme.size_text_x_large)
		i2: make_style(italic, theme.size_text_large)
		i3: make_style(italic, theme.size_text_medium)
		i4: make_style(italic, theme.size_text_small)
		i5: make_style(italic, theme.size_text_x_small)
		i6: make_style(italic, theme.size_text_tiny)
		// Bold+Italic
		bi1: make_style(bold_italic, theme.size_text_x_large)
		bi2: make_style(bold_italic, theme.size_text_large)
		bi3: make_style(bold_italic, theme.size_text_medium)
		bi4: make_style(bold_italic, theme.size_text_small)
		bi5: make_style(bold_italic, theme.size_text_x_small)
		bi6: make_style(bold_italic, theme.size_text_tiny)
		// Mono
		m1: make_style(mono, theme.size_text_x_large + 1)
		m2: make_style(mono, theme.size_text_large + 1)
		m3: make_style(mono, theme.size_text_medium + 1)
		m4: make_style(mono, theme.size_text_small + 1)
		m5: make_style(mono, theme.size_text_x_small + 1)
		m6: make_style(mono, theme.size_text_tiny + 1)
		// Icon Font
		icon1: make_style(icon, theme.size_text_x_large)
		icon2: make_style(icon, theme.size_text_large)
		icon3: make_style(icon, theme.size_text_medium)
		icon4: make_style(icon, theme.size_text_small)
		icon5: make_style(icon, theme.size_text_x_small)
		icon6: make_style(icon, theme.size_text_tiny)

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
		list_box_style:   ListBoxStyle{
			...theme.list_box_style
			subheading_style: TextStyle{
				...bold
			}
		}
		data_grid_style:  DataGridStyle{
			...theme.data_grid_style
			text_style:        normal
			text_style_header: bold
			text_style_filter: normal
		}
		tab_style:        TabStyle{
			...theme.tab_style
			text_style:          normal
			text_style_selected: bold
			text_style_disabled: TextStyle{
				...normal
				color: Color{
					r: normal.color.r
					g: normal.color.g
					b: normal.color.b
					a: 130
				}
			}
		}
		breadcrumb_style: BreadcrumbStyle{
			...theme.breadcrumb_style
			text_style:           normal
			text_style_selected:  bold
			text_style_disabled:  TextStyle{
				...normal
				color: Color{
					r: normal.color.r
					g: normal.color.g
					b: normal.color.b
					a: 130
				}
			}
			text_style_separator: TextStyle{
				...normal
				color: Color{
					r: normal.color.r
					g: normal.color.g
					b: normal.color.b
					a: 160
				}
			}
			text_style_icon:      TextStyle{
				...normal
				family: icon_font_name
				size:   theme.size_text_medium
			}
		}
		// markdown
		markdown_style: MarkdownStyle{
			text:                normal
			h1:                  make_style(bold, theme.size_text_x_large)
			h2:                  make_style(bold, theme.size_text_large)
			h3:                  make_style(bold, theme.size_text_medium)
			h4:                  make_style(bold, theme.size_text_small)
			h5:                  make_style(bold, theme.size_text_x_small)
			h6:                  make_style(bold, theme.size_text_tiny)
			bold:                make_style(bold, theme.size_text_medium)
			italic:              make_style(italic, theme.size_text_medium)
			code:                make_style(mono, theme.size_text_medium + 1)
			code_block_bg:       rgb(40, 44, 52)
			code_keyword_color:  theme.color_select
			code_string_color:   rgb(152, 195, 121)
			code_number_color:   rgb(209, 154, 102)
			code_comment_color:  theme.color_border
			code_operator_color: normal.color
			hr_color:            theme.color_border
			link_color:          theme.color_select
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

// -----------------------------------------------------------------------------
// Theme modification methods
// -----------------------------------------------------------------------------
// These methods allow modifying an existing Theme without going through
// ThemeCfg + theme_maker(). Each returns a new Theme with the specified
// style replaced.

// with_breadcrumb_style returns a new Theme with the breadcrumb style replaced.
pub fn (t Theme) with_breadcrumb_style(style BreadcrumbStyle) Theme {
	return Theme{
		...t
		breadcrumb_style: style
	}
}

// with_button_style returns a new Theme with the button style replaced.
pub fn (t Theme) with_button_style(style ButtonStyle) Theme {
	return Theme{
		...t
		button_style: style
	}
}

// with_color_picker_style returns a new Theme with the color picker style replaced.
pub fn (t Theme) with_color_picker_style(style ColorPickerStyle) Theme {
	return Theme{
		...t
		color_picker_style: style
	}
}

// with_container_style returns a new Theme with the container style replaced.
pub fn (t Theme) with_container_style(style ContainerStyle) Theme {
	return Theme{
		...t
		container_style: style
	}
}

// with_date_picker_style returns a new Theme with the date picker style replaced.
pub fn (t Theme) with_date_picker_style(style DatePickerStyle) Theme {
	return Theme{
		...t
		date_picker_style: style
	}
}

// with_data_grid_style returns a new Theme with the data grid style replaced.
pub fn (t Theme) with_data_grid_style(style DataGridStyle) Theme {
	return Theme{
		...t
		data_grid_style: style
	}
}

// with_dialog_style returns a new Theme with the dialog style replaced.
pub fn (t Theme) with_dialog_style(style DialogStyle) Theme {
	return Theme{
		...t
		dialog_style: style
	}
}

// with_expand_panel_style returns a new Theme with the expand panel style replaced.
pub fn (t Theme) with_expand_panel_style(style ExpandPanelStyle) Theme {
	return Theme{
		...t
		expand_panel_style: style
	}
}

// with_input_style returns a new Theme with the input style replaced.
pub fn (t Theme) with_input_style(style InputStyle) Theme {
	return Theme{
		...t
		input_style: style
	}
}

// with_list_box_style returns a new Theme with the list box style replaced.
pub fn (t Theme) with_list_box_style(style ListBoxStyle) Theme {
	return Theme{
		...t
		list_box_style: style
	}
}

// with_menubar_style returns a new Theme with the menubar style replaced.
pub fn (t Theme) with_menubar_style(style MenubarStyle) Theme {
	return Theme{
		...t
		menubar_style: style
	}
}

// with_progress_bar_style returns a new Theme with the progress bar style replaced.
pub fn (t Theme) with_progress_bar_style(style ProgressBarStyle) Theme {
	return Theme{
		...t
		progress_bar_style: style
	}
}

// with_radio_style returns a new Theme with the radio style replaced.
pub fn (t Theme) with_radio_style(style RadioStyle) Theme {
	return Theme{
		...t
		radio_style: style
	}
}

// with_range_slider_style returns a new Theme with the range slider style replaced.
pub fn (t Theme) with_range_slider_style(style RangeSliderStyle) Theme {
	return Theme{
		...t
		range_slider_style: style
	}
}

// with_rectangle_style returns a new Theme with the rectangle style replaced.
pub fn (t Theme) with_rectangle_style(style RectangleStyle) Theme {
	return Theme{
		...t
		rectangle_style: style
	}
}

// with_scrollbar_style returns a new Theme with the scrollbar style replaced.
pub fn (t Theme) with_scrollbar_style(style ScrollbarStyle) Theme {
	return Theme{
		...t
		scrollbar_style: style
	}
}

// with_select_style returns a new Theme with the select style replaced.
pub fn (t Theme) with_select_style(style SelectStyle) Theme {
	return Theme{
		...t
		select_style: style
	}
}

// with_splitter_style returns a new Theme with the splitter style replaced.
pub fn (t Theme) with_splitter_style(style SplitterStyle) Theme {
	return Theme{
		...t
		splitter_style: style
	}
}

// with_switch_style returns a new Theme with the switch style replaced.
pub fn (t Theme) with_switch_style(style SwitchStyle) Theme {
	return Theme{
		...t
		switch_style: style
	}
}

// with_tab_style returns a new Theme with the tab style replaced.
pub fn (t Theme) with_tab_style(style TabStyle) Theme {
	return Theme{
		...t
		tab_style: style
	}
}

// with_text_style returns a new Theme with the text style replaced.
pub fn (t Theme) with_text_style(style TextStyle) Theme {
	return Theme{
		...t
		text_style: style
	}
}

// with_toggle_style returns a new Theme with the toggle style replaced.
pub fn (t Theme) with_toggle_style(style ToggleStyle) Theme {
	return Theme{
		...t
		toggle_style: style
	}
}

// with_tooltip_style returns a new Theme with the tooltip style replaced.
pub fn (t Theme) with_tooltip_style(style TooltipStyle) Theme {
	return Theme{
		...t
		tooltip_style: style
	}
}

// with_tree_style returns a new Theme with the tree style replaced.
pub fn (t Theme) with_tree_style(style TreeStyle) Theme {
	return Theme{
		...t
		tree_style: style
	}
}

// with_markdown_style returns a new Theme with the markdown style replaced.
pub fn (t Theme) with_markdown_style(style MarkdownStyle) Theme {
	return Theme{
		...t
		markdown_style: style
	}
}

// with_combobox_style returns a new Theme with the combobox style replaced.
pub fn (t Theme) with_combobox_style(style ComboboxStyle) Theme {
	return Theme{
		...t
		combobox_style: style
	}
}

// with_command_palette_style returns a new Theme with the command palette style replaced.
pub fn (t Theme) with_command_palette_style(style CommandPaletteStyle) Theme {
	return Theme{
		...t
		command_palette_style: style
	}
}

// -----------------------------------------------------------------------------
// Bulk color updates
// -----------------------------------------------------------------------------

// ColorOverrides specifies which semantic colors to update across all widget
// styles. Use `none` for colors you don't want to change.
pub struct ColorOverrides {
pub:
	color_background   ?Color
	color_panel        ?Color
	color_interior     ?Color
	color_hover        ?Color
	color_focus        ?Color
	color_active       ?Color
	color_border       ?Color
	color_border_focus ?Color
	color_select       ?Color
}

// with_colors returns a new Theme with the specified colors updated across
// all widget styles. Only non-none colors are changed.
//
// Example:
//   new_theme := theme_dark.with_colors(
//       color_hover: rgb(100, 100, 120)
//       color_select: rgb(80, 120, 200)
//   )
pub fn (t Theme) with_colors(overrides ColorOverrides) Theme {
	// Resolve colors: use override if provided, otherwise keep existing
	bg := overrides.color_background or { t.color_background }
	panel := overrides.color_panel or { t.color_panel }
	interior := overrides.color_interior or { t.color_interior }
	hover := overrides.color_hover or { t.color_hover }
	focus := overrides.color_focus or { t.color_focus }
	active := overrides.color_active or { t.color_active }
	border := overrides.color_border or { t.color_border }
	border_focus := overrides.color_border_focus or { t.button_style.color_border_focus }
	sel := overrides.color_select or { t.color_select }

	return Theme{
		...t
		color_background: bg
		color_panel:      panel
		color_interior:   interior
		color_hover:      hover
		color_focus:      focus
		color_active:     active
		color_border:     border
		color_select:     sel

		color_picker_style: ColorPickerStyle{
			...t.color_picker_style
			color:              interior
			color_hover:        hover
			color_border:       border
			color_border_focus: border_focus
		}
		breadcrumb_style:   BreadcrumbStyle{
			...t.breadcrumb_style
			color_crumb_hover:    hover
			color_crumb_click:    active
			color_content:        panel
			color_content_border: border
		}
		button_style:       ButtonStyle{
			...t.button_style
			color:              interior
			color_border:       border
			color_border_focus: border_focus
			color_click:        focus
			color_focus:        active
			color_hover:        hover
		}
		container_style:    ContainerStyle{
			...t.container_style
		}
		date_picker_style:  DatePickerStyle{
			...t.date_picker_style
			color:              interior
			color_hover:        hover
			color_focus:        focus
			color_click:        active
			color_border:       border
			color_border_focus: sel
			color_select:       sel
		}
		dialog_style:       DialogStyle{
			...t.dialog_style
			color:              panel
			color_border:       border
			color_border_focus: border_focus
		}
		expand_panel_style: ExpandPanelStyle{
			...t.expand_panel_style
			color:              panel
			color_hover:        hover
			color_focus:        focus
			color_border:       border
			color_border_focus: border_focus
		}
		input_style:        InputStyle{
			...t.input_style
			color:              interior
			color_hover:        hover
			color_focus:        interior
			color_click:        active
			color_border:       border
			color_border_focus: border_focus
		}
		list_box_style:     ListBoxStyle{
			...t.list_box_style
			color:              interior
			color_hover:        hover
			color_focus:        focus
			color_border:       border
			color_border_focus: border_focus
			color_select:       sel
		}
		data_grid_style:    DataGridStyle{
			...t.data_grid_style
			color_background:    interior
			color_header:        panel
			color_header_hover:  hover
			color_filter:        interior
			color_quick_filter:  panel
			color_row_hover:     hover
			color_row_selected:  sel
			color_border:        border
			color_resize_handle: border
			color_resize_active: border_focus
		}
		menubar_style:      MenubarStyle{
			...t.menubar_style
			color:              interior
			color_hover:        hover
			color_focus:        focus
			color_border:       border
			color_border_focus: border_focus
			color_select:       sel
		}
		progress_bar_style: ProgressBarStyle{
			...t.progress_bar_style
			color:        interior
			color_bar:    active
			color_border: border
		}
		radio_style:        RadioStyle{
			...t.radio_style
			color:              panel
			color_hover:        hover
			color_focus:        sel
			color_border:       border
			color_border_focus: border_focus
			color_select:       sel
			color_unselect:     active
		}
		range_slider_style: RangeSliderStyle{
			...t.range_slider_style
			color:              interior
			color_left:         active
			color_thumb:        active
			color_focus:        border_focus
			color_hover:        hover
			color_border:       border
			color_border_focus: border_focus
			color_click:        sel
		}
		rectangle_style:    RectangleStyle{
			...t.rectangle_style
			color_border: border
		}
		scrollbar_style:    ScrollbarStyle{
			...t.scrollbar_style
			color_thumb: active
		}
		select_style:       SelectStyle{
			...t.select_style
			color:              interior
			color_hover:        hover
			color_focus:        focus
			color_click:        active
			color_border:       border
			color_border_focus: border_focus
			color_select:       sel
		}
		splitter_style:     SplitterStyle{
			...t.splitter_style
			color_handle:        interior
			color_handle_hover:  hover
			color_handle_active: active
			color_handle_border: border
			color_grip:          sel
			color_button:        interior
			color_button_hover:  hover
			color_button_active: active
		}
		tab_style:          TabStyle{
			...t.tab_style
			color:                  panel
			color_border:           border
			color_content:          panel
			color_content_border:   border
			color_tab:              interior
			color_tab_hover:        hover
			color_tab_focus:        focus
			color_tab_click:        active
			color_tab_selected:     sel
			color_tab_disabled:     panel
			color_tab_border:       border
			color_tab_border_focus: border_focus
		}

		switch_style:          SwitchStyle{
			...t.switch_style
			color:              panel
			color_click:        interior
			color_focus:        interior
			color_hover:        hover
			color_border:       border
			color_border_focus: border_focus
			color_select:       sel
			color_unselect:     active
		}
		toggle_style:          ToggleStyle{
			...t.toggle_style
			color:              panel
			color_border:       border
			color_border_focus: border_focus
			color_click:        interior
			color_focus:        interior
			color_hover:        hover
			color_select:       interior
		}
		tooltip_style:         TooltipStyle{
			...t.tooltip_style
			color:              interior
			color_hover:        hover
			color_focus:        focus
			color_click:        active
			color_border:       border
			color_border_focus: border_focus
		}
		tree_style:            TreeStyle{
			...t.tree_style
			color_hover:        hover
			color_focus:        focus
			color_border_focus: border_focus
		}
		combobox_style:        ComboboxStyle{
			...t.combobox_style
			color:              interior
			color_hover:        hover
			color_focus:        interior
			color_border:       border
			color_border_focus: border_focus
			color_highlight:    sel
		}
		command_palette_style: CommandPaletteStyle{
			...t.command_palette_style
			color:           panel
			color_border:    border
			color_highlight: sel
		}
	}
}
