module gui

// Theme describes a theme in GUI. It's large in part because GUI
// allows every view it supports to have its own styles. Normally,
// colors and fonts are shared across all views but you have the
// option to change every aspect. Themes are granular.
pub struct Theme {
pub:
	cfg              ThemeCfg = theme_dark_cfg
	name             string   = 'default' @[required]
	color_background Color    = color_background_dark // background of the window
	color_panel      Color    = color_panel_dark      // use for side panels, or groups of controls
	color_interior   Color    = color_interior_dark   // use for the interior of controls like buttons
	color_hover      Color    = color_hover_dark      // mostly mouse hovers
	color_focus      Color    = color_focus_dark      // usually keyboard focus (active/focus swapped if it looks better, e.g. button)
	color_active     Color    = color_active_dark     // use for clicks and inactivity
	color_border     Color    = color_border_dark     // borders
	color_select     Color    = color_select_dark     // links and selected
	titlebar_dark    bool

	breadcrumb_style      BreadcrumbStyle
	button_style          ButtonStyle
	color_picker_style    ColorPickerStyle
	container_style       ContainerStyle
	date_picker_style     DatePickerStyle
	data_grid_style       DataGridStyle
	dialog_style          DialogStyle
	expand_panel_style    ExpandPanelStyle
	input_style           InputStyle
	list_box_style        ListBoxStyle
	menubar_style         MenubarStyle
	progress_bar_style    ProgressBarStyle
	radio_style           RadioStyle
	range_slider_style    RangeSliderStyle
	rectangle_style       RectangleStyle
	scrollbar_style       ScrollbarStyle
	select_style          SelectStyle
	splitter_style        SplitterStyle
	switch_style          SwitchStyle
	tab_style             TabStyle
	text_style            TextStyle
	text_style_bold       TextStyle
	toggle_style          ToggleStyle
	tooltip_style         TooltipStyle
	tree_style            TreeStyle
	combobox_style        ComboboxStyle
	command_palette_style CommandPaletteStyle
	markdown_style        MarkdownStyle
	toast_style           ToastStyle

	// n's and b's are convenience configs for sizing
	// similar to H1-H6 in html markup. n3 is the
	// same as normal size font used by default in
	// text views
	n1 TextStyle
	n2 TextStyle
	n3 TextStyle
	n4 TextStyle
	n5 TextStyle
	n6 TextStyle
	// Bold
	b1 TextStyle
	b2 TextStyle
	b3 TextStyle
	b4 TextStyle
	b5 TextStyle
	b6 TextStyle
	// italic
	i1 TextStyle
	i2 TextStyle
	i3 TextStyle
	i4 TextStyle
	i5 TextStyle
	i6 TextStyle
	// Bold+Italic
	bi1 TextStyle
	bi2 TextStyle
	bi3 TextStyle
	bi4 TextStyle
	bi5 TextStyle
	bi6 TextStyle
	// Mono
	m1 TextStyle
	m2 TextStyle
	m3 TextStyle
	m4 TextStyle
	m5 TextStyle
	m6 TextStyle
	// Icon
	icon1 TextStyle
	icon2 TextStyle
	icon3 TextStyle
	icon4 TextStyle
	icon5 TextStyle
	icon6 TextStyle

	padding_small  Padding = padding_small
	padding_medium Padding = padding_medium
	padding_large  Padding = padding_large
	size_border    f32

	radius_small  f32 = radius_small
	radius_medium f32 = radius_medium
	radius_large  f32 = radius_large

	spacing_small  f32 = spacing_small
	spacing_medium f32 = spacing_medium
	spacing_large  f32 = spacing_large
	spacing_text   f32 = text_line_spacing // additional line height

	size_text_tiny    f32 = size_text_tiny
	size_text_x_small f32 = size_text_x_small
	size_text_small   f32 = size_text_small
	size_text_medium  f32 = size_text_medium
	size_text_large   f32 = size_text_large
	size_text_x_large f32 = size_text_x_large

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
	color_success      Color = Color{46, 160, 67, 255}
	color_warning      Color = Color{210, 153, 34, 255}
	color_error        Color = Color{218, 54, 51, 255}
	titlebar_dark      bool
	fill               bool    = true
	fill_border        bool    = true
	padding            Padding = padding_medium
	size_border        f32

	radius        f32       = radius_medium
	radius_border f32       = radius_border
	text_style    TextStyle = text_style_dark

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

	size_text_tiny    f32 = size_text_tiny
	size_text_x_small f32 = size_text_x_small
	size_text_small   f32 = size_text_small
	size_text_medium  f32 = size_text_medium
	size_text_large   f32 = size_text_large
	size_text_x_large f32 = size_text_x_large

	scroll_multiplier f32 = scroll_multiplier
	scroll_delta_line f32 = scroll_delta_line
	scroll_delta_page f32 = scroll_delta_page
	scroll_gap_edge   f32 = scroll_gap_edge // gap between edge of scrollbar and container
	scroll_gap_end    f32 = scroll_gap_end  // gap between end of scrollbar and container

	// Widget-specific sizes (configurable via ThemeCfg)
	size_switch_width        f32 = 36 // switch toggle width
	size_switch_height       f32 = 22 // switch toggle height
	size_radio               f32 = 16 // radio button diameter
	size_scrollbar           f32 = 7  // scrollbar track size
	size_scrollbar_min_thumb f32 = 20 // minimum scrollbar thumb size
	size_progress_bar        f32 = 10 // progress bar height
	size_range_slider        f32 = 7  // range slider track size
	size_range_slider_thumb  f32 = 15 // range slider thumb size
	size_splitter_handle     f32 = 9  // splitter divider size

	// Submenu width constraints
	width_submenu_min f32 = 50
	width_submenu_max f32 = 200
}
