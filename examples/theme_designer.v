import gui

// Theme Designer
// =============================
// Interactive theme editor with live preview.
// Left panel: color/style controls
// Right panel: component preview

// Layout constants
const window_width = 1000
const window_height = 700
const editor_max_width = 260
const scrollbar_gap = 4
const row_spacing = 2
const button_spacing = 3
const section_padding = 8
const slider_value_gap = 3

// Label widths
const label_width_small = 15
const label_width_medium = 50
const label_width_gradient = 18
const label_width_stop = 10
const value_width_small = 22
const value_width_medium = 25
const value_width_large = 28

// Preview element sizes
const color_swatch_size = 40
const color_swatch_height = 20
const shadow_preview_width = 60
const shadow_preview_height = 30
const gradient_preview_width = 50
const gradient_preview_height = 20
const grad_swatch_width = 16
const grad_swatch_height = 14
const palette_swatch_size = 50
const input_width = 180
const progress_height_large = 20
const progress_height_small = 8
const bottom_padding_height = 20

// Slider ranges
const color_max = f32(255)
const radius_max = f32(20)
const border_max = f32(5)
const spacing_max = f32(30)
const font_size_min = f32(10)
const font_size_max = f32(32)
const shadow_offset_min = f32(-20)
const shadow_offset_max = f32(20)
const shadow_blur_max = f32(20)
const shadow_spread_min = f32(-10)
const shadow_spread_max = f32(20)
const slider_max = f32(100)

// Typography
const heading1_size_offset = f32(12)
const heading2_size_offset = f32(6)
const secondary_size_offset = f32(-2)
const font_info_size = f32(12)
const muted_alpha = u8(180)
const subtle_alpha = u8(150)

// Scroll IDs
const id_scroll_editor = 1
const id_scroll_preview = 2

// Focus IDs for editor panel
const id_focus_preset_dark = 10
const id_focus_preset_light = 11
const id_focus_preset_dark_bordered = 12
const id_focus_preset_light_bordered = 13
const id_focus_preset_blue_bordered = 14
const id_focus_bg_r = 20
const id_focus_bg_g = 21
const id_focus_bg_b = 22
const id_focus_panel_r = 23
const id_focus_panel_g = 24
const id_focus_panel_b = 25
const id_focus_text_r = 26
const id_focus_text_g = 27
const id_focus_text_b = 28
const id_focus_accent_r = 29
const id_focus_accent_g = 30
const id_focus_accent_b = 31
const id_focus_border_r = 32
const id_focus_border_g = 33
const id_focus_border_b = 34
const id_focus_style_radius = 35
const id_focus_style_border = 36
const id_focus_style_spacing = 37
const id_focus_font_system = 38
const id_focus_font_serif = 39
const id_focus_font_mono = 40
const id_focus_font_size = 41
const id_focus_shadow_offset_x = 42
const id_focus_shadow_offset_y = 43
const id_focus_shadow_blur = 44
const id_focus_shadow_spread = 45
const id_focus_shadow_alpha = 46
const id_focus_grad_enable = 47
const id_focus_grad_linear = 48
const id_focus_grad_radial = 49
const id_focus_grad_start_x = 50
const id_focus_grad_start_y = 51
const id_focus_grad_end_x = 52
const id_focus_grad_end_y = 53
const id_focus_grad_stop1_r = 54
const id_focus_grad_stop1_g = 55
const id_focus_grad_stop1_b = 56
const id_focus_grad_stop1_pos = 57
const id_focus_grad_stop2_r = 58
const id_focus_grad_stop2_g = 59
const id_focus_grad_stop2_b = 60
const id_focus_grad_stop2_pos = 61

// Focus IDs for preview panel
const id_focus_btn_primary = 100
const id_focus_btn_accent = 101
const id_focus_btn_disabled = 102
const id_focus_input_text = 200
const id_focus_input_password = 201

@[heap]
struct ThemeEditorState {
pub mut:
	// Colors (RGB components)
	bg_r     f32 = 48
	bg_g     f32 = 48
	bg_b     f32 = 48
	panel_r  f32 = 64
	panel_g  f32 = 64
	panel_b  f32 = 64
	text_r   f32 = 225
	text_g   f32 = 225
	text_b   f32 = 225
	accent_r f32 = 65
	accent_g f32 = 105
	accent_b f32 = 225
	border_r f32 = 100
	border_g f32 = 100
	border_b f32 = 100
	// Style
	border_radius f32 = 5.5
	border_size   f32 = 1
	spacing       f32 = 10
	// Typography
	font_family string = 'System'
	font_size   f32    = 16
	// Shadow
	shadow_offset_x f32 = 2
	shadow_offset_y f32 = 2
	shadow_blur     f32 = 4
	shadow_spread   f32
	shadow_alpha    f32 = 80
	// Gradient
	gradient_enabled bool
	gradient_type    string = 'Linear'
	gradient_start_x f32
	gradient_start_y f32
	gradient_end_x   f32 = 1.0
	gradient_end_y   f32 = 1.0
	grad_stop1_pos   f32
	grad_stop1_r     f32 = 100
	grad_stop1_g     f32 = 100
	grad_stop1_b     f32 = 200
	grad_stop2_pos   f32 = 1.0
	grad_stop2_r     f32 = 50
	grad_stop2_g     f32 = 50
	grad_stop2_b     f32 = 100
	// Preview state
	input_text   string = 'Sample text'
	toggle_state bool
	switch_state bool
	progress     f32 = 0.65
	slider_value f32 = 50
}

fn main() {
	mut window := gui.window(
		title:        'Theme Designer'
		state:        &ThemeEditorState{}
		width:        window_width
		height:       window_height
		cursor_blink: true
		on_init:      fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	return gui.row(
		width:   w
		height:  h
		padding: gui.padding_none
		sizing:  gui.fixed_fixed
		spacing: row_spacing
		content: [
			editor_panel(window),
			preview_panel(window),
		]
	)
}

// ============================================================
// Helper Functions
// ============================================================

fn label_style() gui.TextStyle {
	return gui.theme().n5
}

fn get_color(app &ThemeEditorState, prefix string) gui.Color {
	r, g, b := get_color_rgb(prefix, app)
	return gui.rgb(u8(r), u8(g), u8(b))
}

fn get_color_rgb(prefix string, app &ThemeEditorState) (f32, f32, f32) {
	return match prefix {
		'bg' { app.bg_r, app.bg_g, app.bg_b }
		'panel' { app.panel_r, app.panel_g, app.panel_b }
		'text' { app.text_r, app.text_g, app.text_b }
		'accent' { app.accent_r, app.accent_g, app.accent_b }
		'border' { app.border_r, app.border_g, app.border_b }
		else { f32(0), f32(0), f32(0) }
	}
}

fn get_font_family(app &ThemeEditorState) string {
	return match app.font_family {
		'Serif' { 'Georgia, Times, Serif' }
		'Mono' { 'Menlo, Monaco, Mono' }
		else { '' }
	}
}

fn get_text_style(app &ThemeEditorState) gui.TextStyle {
	return gui.TextStyle{
		family: get_font_family(app)
		color:  get_color(app, 'text')
		size:   app.font_size
	}
}

fn get_box_shadow(app &ThemeEditorState) &gui.BoxShadow {
	return &gui.BoxShadow{
		color:         gui.rgba(0, 0, 0, u8(app.shadow_alpha))
		offset_x:      app.shadow_offset_x
		offset_y:      app.shadow_offset_y
		blur_radius:   app.shadow_blur
		spread_radius: app.shadow_spread
	}
}

fn get_gradient(app &ThemeEditorState) &gui.Gradient {
	if !app.gradient_enabled {
		return unsafe { nil }
	}
	return &gui.Gradient{
		type:    if app.gradient_type == 'Radial' { .radial } else { .linear }
		start_x: app.gradient_start_x
		start_y: app.gradient_start_y
		end_x:   app.gradient_end_x
		end_y:   app.gradient_end_y
		stops:   [
			gui.GradientStop{
				color: gui.rgb(u8(app.grad_stop1_r), u8(app.grad_stop1_g), u8(app.grad_stop1_b))
				pos:   app.grad_stop1_pos
			},
			gui.GradientStop{
				color: gui.rgb(u8(app.grad_stop2_r), u8(app.grad_stop2_g), u8(app.grad_stop2_b))
				pos:   app.grad_stop2_pos
			},
		]
	}
}

fn toggle_button(label string, is_selected bool, id_focus u32, on_click fn (&gui.Layout, mut gui.Event, mut gui.Window)) gui.View {
	return gui.button(
		id_focus:     id_focus
		padding:      gui.padding(2, 4, 2, 4)
		color:        if is_selected { gui.theme().color_active } else { gui.theme().color_interior }
		color_border: if is_selected { gui.theme().color_select } else { gui.theme().color_border }
		size_border:  1
		radius:       gui.radius_small
		content:      [gui.text(text: label, text_style: label_style())]
		on_click:     on_click
	)
}

fn slider_row(label string, value f32, min f32, max f32, label_width int, value_width int, id string, round bool, id_focus u32, decimals int, on_change fn (f32, mut gui.Event, mut gui.Window)) gui.View {
	mut content := []gui.View{cap: 3}
	content << gui.text(text: label, min_width: label_width, text_style: label_style())
	content << gui.range_slider(
		id:          id
		id_focus:    id_focus
		value:       value
		min:         min
		max:         max
		round_value: round
		sizing:      gui.fill_fit
		on_change:   on_change
	)
	if value_width > 0 {
		value_text := if decimals > 0 { '${value:.2}' } else { '${int(value)}' }
		content << gui.row(
			padding: gui.padding(0, 0, 0, slider_value_gap)
			content: [
				gui.text(text: value_text, min_width: value_width, text_style: label_style()),
			]
		)
	}
	return gui.row(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		v_align: .middle
		spacing: gui.spacing_small
		content: content
	)
}

// ============================================================
// Editor Panel (Left)
// ============================================================

fn editor_panel(window &gui.Window) gui.View {
	return gui.column(
		id_scroll:       id_scroll_editor
		scrollbar_cfg_y: &gui.ScrollbarCfg{
			gap_edge: scrollbar_gap
		}
		sizing:          gui.fill_fill
		max_width:       editor_max_width
		color:           gui.theme().color_panel
		spacing:         gui.spacing_medium
		content:         [
			preset_buttons(),
			section_title('Background Color'),
			color_sliders('bg', window),
			section_title('Panel Color'),
			color_sliders('panel', window),
			section_title('Text Color'),
			color_sliders('text', window),
			section_title('Accent Color'),
			color_sliders('accent', window),
			section_title('Border Color'),
			color_sliders('border', window),
			section_title('Style Properties'),
			style_sliders(window),
			section_title('Typography'),
			typeface_picker(window),
			section_title('Box Shadow'),
			shadow_sliders(window),
			section_title('Gradient'),
			gradient_controls(window),
			gui.row(sizing: gui.fill_fit, height: bottom_padding_height),
		]
	)
}

fn section_title(title string) gui.View {
	return gui.column(
		sizing:  gui.fill_fit
		spacing: row_spacing
		padding: gui.padding(8, 0, 0, 0)
		content: [
			gui.text(text: title, text_style: gui.theme().b3),
			gui.row(
				height:  1
				sizing:  gui.fill_fit
				padding: gui.padding_none
				color:   gui.theme().color_active
			),
		]
	)
}

fn preset_buttons() gui.View {
	return gui.column(
		sizing:  gui.fill_fit
		spacing: row_spacing
		padding: gui.padding_none
		content: [
			gui.text(text: 'Presets', text_style: gui.theme().b3),
			gui.row(
				sizing:  gui.fill_fit
				padding: gui.padding_none
				spacing: button_spacing
				content: [
					preset_button('Drk', 'Dark', id_focus_preset_dark),
					preset_button('Lgt', 'Light', id_focus_preset_light),
					preset_button('D+B', 'Dark Bordered', id_focus_preset_dark_bordered),
					preset_button('L+B', 'Light Bordered', id_focus_preset_light_bordered),
					preset_button('Blu', 'Blue Bordered', id_focus_preset_blue_bordered),
				]
			),
		]
	)
}

fn preset_button(label string, tooltip_text string, id_focus u32) gui.View {
	return gui.button(
		id_focus:     id_focus
		padding:      gui.padding(2, 5, 2, 5)
		color:        gui.theme().color_interior
		color_border: gui.theme().color_border
		size_border:  1
		radius:       gui.radius_small
		tooltip:      &gui.TooltipCfg{
			id:      'preset_${label}'
			content: [gui.text(text: tooltip_text)]
		}
		content:      [gui.text(text: label, text_style: label_style())]
		on_click:     fn [tooltip_text] (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			apply_preset(tooltip_text, mut w)
		}
	)
}

fn apply_preset(name string, mut w gui.Window) {
	theme := match name {
		'Dark' { gui.theme_dark }
		'Light' { gui.theme_light }
		'Dark Bordered' { gui.theme_dark_bordered }
		'Light Bordered' { gui.theme_light_bordered }
		'Blue Bordered' { gui.theme_blue_bordered }
		else { gui.theme_dark_bordered }
	}
	w.set_theme(theme)

	mut app := w.state[ThemeEditorState]()
	app.bg_r, app.bg_g, app.bg_b = theme.color_background.r, theme.color_background.g, theme.color_background.b
	app.panel_r, app.panel_g, app.panel_b = theme.color_panel.r, theme.color_panel.g, theme.color_panel.b
	app.text_r, app.text_g, app.text_b = theme.n1.color.r, theme.n1.color.g, theme.n1.color.b
	app.accent_r, app.accent_g, app.accent_b = theme.color_select.r, theme.color_select.g, theme.color_select.b
	app.border_r, app.border_g, app.border_b = theme.color_border.r, theme.color_border.g, theme.color_border.b
	app.border_size = theme.button_style.size_border
	app.border_radius = theme.button_style.radius
}

fn color_sliders(prefix string, window &gui.Window) gui.View {
	app := window.state[ThemeEditorState]()
	r, g, b := get_color_rgb(prefix, app)
	base_id := u32(match prefix {
		'bg' { id_focus_bg_r }
		'panel' { id_focus_panel_r }
		'text' { id_focus_text_r }
		'accent' { id_focus_accent_r }
		'border' { id_focus_border_r }
		else { 0 }
	})

	return gui.column(
		sizing:  gui.fill_fit
		spacing: row_spacing
		padding: gui.padding_none
		content: [
			color_slider_row('R', r, prefix, 'r', base_id),
			color_slider_row('G', g, prefix, 'g', base_id + 1),
			color_slider_row('B', b, prefix, 'b', base_id + 2),
			color_preview(prefix, app),
		]
	)
}

fn color_slider_row(label string, value f32, prefix string, component string, id_focus u32) gui.View {
	return slider_row(label, value, 0, color_max, label_width_small, value_width_large,
		'${prefix}_${component}', true, id_focus, 0, make_color_handler(prefix, component))
}

fn make_color_handler(prefix string, component string) fn (f32, mut gui.Event, mut gui.Window) {
	return fn [prefix, component] (value f32, mut e gui.Event, mut w gui.Window) {
		mut app := w.state[ThemeEditorState]()
		match prefix {
			'bg' {
				match component {
					'r' { app.bg_r = value }
					'g' { app.bg_g = value }
					'b' { app.bg_b = value }
					else {}
				}
			}
			'panel' {
				match component {
					'r' { app.panel_r = value }
					'g' { app.panel_g = value }
					'b' { app.panel_b = value }
					else {}
				}
			}
			'text' {
				match component {
					'r' { app.text_r = value }
					'g' { app.text_g = value }
					'b' { app.text_b = value }
					else {}
				}
			}
			'accent' {
				match component {
					'r' { app.accent_r = value }
					'g' { app.accent_g = value }
					'b' { app.accent_b = value }
					else {}
				}
			}
			'border' {
				match component {
					'r' { app.border_r = value }
					'g' { app.border_g = value }
					'b' { app.border_b = value }
					else {}
				}
			}
			else {}
		}
	}
}

fn color_preview(prefix string, app &ThemeEditorState) gui.View {
	r, g, b := get_color_rgb(prefix, app)
	return gui.row(
		sizing:  gui.fill_fit
		v_align: .middle
		spacing: gui.spacing_small
		content: [
			gui.row(
				width:        color_swatch_size
				height:       color_swatch_height
				sizing:       gui.fixed_fixed
				color:        gui.rgb(u8(r), u8(g), u8(b))
				color_border: gui.theme().color_border
				size_border:  1
				radius:       gui.radius_small
			),
			gui.text(text: '${int(r)},${int(g)},${int(b)}', text_style: gui.theme().m5),
		]
	)
}

fn style_sliders(window &gui.Window) gui.View {
	app := window.state[ThemeEditorState]()
	return gui.column(
		sizing:  gui.fill_fit
		spacing: row_spacing
		padding: gui.padding_none
		content: [
			slider_row('Radius', app.border_radius, 0, radius_max, label_width_medium,
				value_width_medium, 'style_radius', true, id_focus_style_radius, 0, make_style_handler('radius')),
			slider_row('Border', app.border_size, 0, border_max, label_width_medium, value_width_medium,
				'style_border', true, id_focus_style_border, 0, make_style_handler('border_size')),
			slider_row('Spacing', app.spacing, 0, spacing_max, label_width_medium, value_width_medium,
				'style_spacing', true, id_focus_style_spacing, 0, make_style_handler('spacing')),
		]
	)
}

fn make_style_handler(field string) fn (f32, mut gui.Event, mut gui.Window) {
	return fn [field] (value f32, mut e gui.Event, mut w gui.Window) {
		mut app := w.state[ThemeEditorState]()
		match field {
			'radius' { app.border_radius = value }
			'border_size' { app.border_size = value }
			'spacing' { app.spacing = value }
			else {}
		}
	}
}

fn typeface_picker(window &gui.Window) gui.View {
	app := window.state[ThemeEditorState]()
	return gui.column(
		sizing:  gui.fill_fit
		spacing: row_spacing
		padding: gui.padding_none
		content: [
			gui.row(
				sizing:  gui.fill_fit
				padding: gui.padding_none
				v_align: .middle
				spacing: gui.spacing_small
				content: [
					gui.text(text: 'Family', min_width: 45),
					font_button('System', id_focus_font_system, app),
					font_button('Serif', id_focus_font_serif, app),
					font_button('Mono', id_focus_font_mono, app),
				]
			),
			slider_row('Size', app.font_size, font_size_min, font_size_max, 45, value_width_small,
				'font_size', true, id_focus_font_size, 0, fn (value f32, mut _ gui.Event, mut w gui.Window) {
				mut state := w.state[ThemeEditorState]()
				state.font_size = value
			}),
			typeface_preview(app),
		]
	)
}

fn font_button(name string, id_focus u32, app &ThemeEditorState) gui.View {
	return toggle_button(name, app.font_family == name, id_focus, fn [name] (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
		mut state := w.state[ThemeEditorState]()
		state.font_family = name
	})
}

fn typeface_preview(app &ThemeEditorState) gui.View {
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_small
		color:   gui.theme().color_interior
		radius:  gui.radius_small
		content: [
			gui.text(text: 'Aa Bb Cc 123', text_style: get_text_style(app)),
		]
	)
}

fn shadow_sliders(window &gui.Window) gui.View {
	app := window.state[ThemeEditorState]()
	return gui.column(
		sizing:  gui.fill_fit
		spacing: row_spacing
		padding: gui.padding_none
		content: [
			slider_row('Offset X', app.shadow_offset_x, shadow_offset_min, shadow_offset_max,
				label_width_medium, value_width_medium, 'shadow_offset_x', true, id_focus_shadow_offset_x,
				0, make_shadow_handler('offset_x')),
			slider_row('Offset Y', app.shadow_offset_y, shadow_offset_min, shadow_offset_max,
				label_width_medium, value_width_medium, 'shadow_offset_y', true, id_focus_shadow_offset_y,
				0, make_shadow_handler('offset_y')),
			slider_row('Blur', app.shadow_blur, 0, shadow_blur_max, label_width_medium,
				value_width_medium, 'shadow_blur', true, id_focus_shadow_blur, 0, make_shadow_handler('blur')),
			slider_row('Spread', app.shadow_spread, shadow_spread_min, shadow_spread_max,
				label_width_medium, value_width_medium, 'shadow_spread', true, id_focus_shadow_spread,
				0, make_shadow_handler('spread')),
			slider_row('Opacity', app.shadow_alpha, 0, color_max, label_width_medium,
				value_width_medium, 'shadow_alpha', true, id_focus_shadow_alpha, 0, make_shadow_handler('alpha')),
			shadow_preview(app),
		]
	)
}

fn make_shadow_handler(field string) fn (f32, mut gui.Event, mut gui.Window) {
	return fn [field] (value f32, mut e gui.Event, mut w gui.Window) {
		mut app := w.state[ThemeEditorState]()
		match field {
			'offset_x' { app.shadow_offset_x = value }
			'offset_y' { app.shadow_offset_y = value }
			'blur' { app.shadow_blur = value }
			'spread' { app.shadow_spread = value }
			'alpha' { app.shadow_alpha = value }
			else {}
		}
	}
}

fn shadow_preview(app &ThemeEditorState) gui.View {
	return gui.row(
		sizing:  gui.fill_fit
		padding: gui.padding_small
		h_align: .center
		content: [
			gui.row(
				width:  shadow_preview_width
				height: shadow_preview_height
				sizing: gui.fixed_fixed
				color:  gui.theme().color_interior
				radius: app.border_radius
				shadow: get_box_shadow(app)
			),
		]
	)
}

fn gradient_controls(window &gui.Window) gui.View {
	app := window.state[ThemeEditorState]()
	return gui.column(
		sizing:  gui.fill_fit
		spacing: row_spacing
		padding: gui.padding(0, section_padding, 0, section_padding)
		content: [
			gui.row(
				sizing:  gui.fill_fit
				padding: gui.padding_none
				v_align: .middle
				spacing: gui.spacing_small
				content: [
					gui.switch(
						id_focus: id_focus_grad_enable
						select:   app.gradient_enabled
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut state := w.state[ThemeEditorState]()
							state.gradient_enabled = !state.gradient_enabled
						}
					),
					grad_type_button('Lin', 'Linear', id_focus_grad_linear, app),
					grad_type_button('Rad', 'Radial', id_focus_grad_radial, app),
					gradient_preview(app),
				]
			),
			slider_row('X1', app.gradient_start_x, 0, 1.0, label_width_gradient, value_width_medium,
				'grad_start_x', false, id_focus_grad_start_x, 2, make_grad_dir_handler('start_x')),
			slider_row('Y1', app.gradient_start_y, 0, 1.0, label_width_gradient, value_width_medium,
				'grad_start_y', false, id_focus_grad_start_y, 2, make_grad_dir_handler('start_y')),
			slider_row('X2', app.gradient_end_x, 0, 1.0, label_width_gradient, value_width_medium,
				'grad_end_x', false, id_focus_grad_end_x, 2, make_grad_dir_handler('end_x')),
			slider_row('Y2', app.gradient_end_y, 0, 1.0, label_width_gradient, value_width_medium,
				'grad_end_y', false, id_focus_grad_end_y, 2, make_grad_dir_handler('end_y')),
			grad_stop_row('1', app.grad_stop1_r, app.grad_stop1_g, app.grad_stop1_b, app.grad_stop1_pos,
				'stop1', id_focus_grad_stop1_r),
			grad_stop_row('2', app.grad_stop2_r, app.grad_stop2_g, app.grad_stop2_b, app.grad_stop2_pos,
				'stop2', id_focus_grad_stop2_r),
		]
	)
}

fn grad_type_button(label string, type_name string, id_focus u32, app &ThemeEditorState) gui.View {
	return toggle_button(label, app.gradient_type == type_name, id_focus, fn [type_name] (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
		mut state := w.state[ThemeEditorState]()
		state.gradient_type = type_name
	})
}

fn make_grad_dir_handler(field string) fn (f32, mut gui.Event, mut gui.Window) {
	return fn [field] (v f32, mut _ gui.Event, mut w gui.Window) {
		mut state := w.state[ThemeEditorState]()
		match field {
			'start_x' { state.gradient_start_x = v }
			'start_y' { state.gradient_start_y = v }
			'end_x' { state.gradient_end_x = v }
			'end_y' { state.gradient_end_y = v }
			else {}
		}
	}
}

fn grad_stop_row(label string, r f32, g f32, b f32, pos f32, stop string, id_focus_base u32) gui.View {
	return gui.row(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		v_align: .middle
		spacing: row_spacing
		content: [
			gui.text(text: label, min_width: label_width_stop, text_style: label_style()),
			gui.row(
				width:        grad_swatch_width
				height:       grad_swatch_height
				sizing:       gui.fixed_fixed
				color:        gui.rgb(u8(r), u8(g), u8(b))
				color_border: gui.theme().color_border
				size_border:  1
				radius:       row_spacing
			),
			gui.range_slider(
				id:          'grad_${stop}_r'
				id_focus:    id_focus_base
				value:       r
				min:         0
				max:         color_max
				round_value: true
				sizing:      gui.fill_fit
				on_change:   make_grad_handler(stop, 'r')
			),
			gui.range_slider(
				id:          'grad_${stop}_g'
				id_focus:    id_focus_base + 1
				value:       g
				min:         0
				max:         color_max
				round_value: true
				sizing:      gui.fill_fit
				on_change:   make_grad_handler(stop, 'g')
			),
			gui.range_slider(
				id:          'grad_${stop}_b'
				id_focus:    id_focus_base + 2
				value:       b
				min:         0
				max:         color_max
				round_value: true
				sizing:      gui.fill_fit
				on_change:   make_grad_handler(stop, 'b')
			),
			gui.range_slider(
				id:        'grad_${stop}_pos'
				id_focus:  id_focus_base + 3
				value:     pos
				min:       0
				max:       1.0
				sizing:    gui.fill_fit
				on_change: make_grad_handler(stop, 'pos')
			),
		]
	)
}

fn make_grad_handler(stop string, field string) fn (f32, mut gui.Event, mut gui.Window) {
	return fn [stop, field] (value f32, mut _ gui.Event, mut w gui.Window) {
		mut app := w.state[ThemeEditorState]()
		if stop == 'stop1' {
			match field {
				'r' { app.grad_stop1_r = value }
				'g' { app.grad_stop1_g = value }
				'b' { app.grad_stop1_b = value }
				'pos' { app.grad_stop1_pos = value }
				else {}
			}
		} else {
			match field {
				'r' { app.grad_stop2_r = value }
				'g' { app.grad_stop2_g = value }
				'b' { app.grad_stop2_b = value }
				'pos' { app.grad_stop2_pos = value }
				else {}
			}
		}
	}
}

fn gradient_preview(app &ThemeEditorState) gui.View {
	return gui.row(
		width:    gradient_preview_width
		height:   gradient_preview_height
		sizing:   gui.fixed_fixed
		radius:   button_spacing
		gradient: get_gradient(app)
		color:    gui.theme().color_interior
	)
}

// ============================================================
// Preview Panel (Right)
// ============================================================

fn preview_panel(window &gui.Window) gui.View {
	app := window.state[ThemeEditorState]()

	bg_color := get_color(app, 'bg')
	panel_color := get_color(app, 'panel')
	text_color := get_color(app, 'text')
	accent_color := get_color(app, 'accent')
	border_color := get_color(app, 'border')
	text_style := get_text_style(app)

	return gui.column(
		id_scroll:       id_scroll_preview
		scrollbar_cfg_y: &gui.ScrollbarCfg{
			gap_edge: scrollbar_gap
		}
		sizing:          gui.fill_fill
		color:           bg_color
		spacing:         int(app.spacing)
		padding:         gui.padding(0, 20, 10, 10)
		content:         [
			preview_section_title('Component Preview', text_color, border_color),
			preview_section('Buttons', text_style, panel_color, border_color, app, [
				gui.row(
					spacing: int(app.spacing)
					content: [
						preview_button('Primary', id_focus_btn_primary, panel_color, border_color,
							text_style, app, false),
						preview_button('Accent', id_focus_btn_accent, accent_color, accent_color,
							text_style, app, false),
						preview_button('Disabled', id_focus_btn_disabled, panel_color,
							border_color, text_style, app, true),
					]
				),
			]),
			preview_section('Text Inputs', text_style, panel_color, border_color, app,
				[
				gui.row(
					spacing: int(app.spacing)
					content: [
						preview_input(id_focus_input_text, false, panel_color, border_color,
							text_style, app),
						preview_input(id_focus_input_password, true, panel_color, border_color,
							text_style, app),
					]
				),
			]),
			preview_section('Toggles & Switches', text_style, panel_color, border_color,
				app, [
				gui.row(
					spacing: int(app.spacing)
					v_align: .middle
					content: [
						gui.toggle(
							label:      'Toggle'
							select:     app.toggle_state
							text_style: text_style
							on_click:   fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
								mut state := w.state[ThemeEditorState]()
								state.toggle_state = !state.toggle_state
							}
						),
						gui.switch(
							label:      'Switch'
							select:     app.switch_state
							text_style: text_style
							on_click:   fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
								mut state := w.state[ThemeEditorState]()
								state.switch_state = !state.switch_state
							}
						),
					]
				),
			]),
			preview_section('Progress Bars', text_style, panel_color, border_color, app,
				[
				gui.column(
					spacing: int(app.spacing)
					sizing:  gui.fill_fit
					padding: gui.padding_none
					content: [
						gui.progress_bar(
							sizing:     gui.fill_fit
							height:     progress_height_large
							percent:    app.progress
							color:      panel_color
							color_bar:  accent_color
							radius:     app.border_radius
							text_style: text_style
						),
						gui.progress_bar(
							sizing:    gui.fill_fit
							height:    progress_height_small
							percent:   app.progress
							color:     panel_color
							color_bar: accent_color
							radius:    app.border_radius
							text_show: false
						),
					]
				),
			]),
			preview_section('Range Sliders', text_style, panel_color, border_color, app,
				[
				gui.row(
					spacing: int(app.spacing)
					v_align: .middle
					sizing:  gui.fill_fit
					content: [
						gui.range_slider(
							id:           'preview_slider'
							value:        app.slider_value
							min:          0
							max:          slider_max
							round_value:  true
							sizing:       gui.fill_fit
							color:        panel_color
							color_border: border_color
							color_thumb:  accent_color
							color_left:   accent_color
							on_change:    fn (value f32, mut _ gui.Event, mut w gui.Window) {
								mut state := w.state[ThemeEditorState]()
								state.slider_value = value
							}
						),
						gui.text(
							text:       '${int(app.slider_value)}%'
							text_style: text_style
							min_width:  label_width_medium
						),
					]
				),
			]),
			preview_section('Color Palette', text_style, panel_color, border_color, app,
				[
				gui.row(
					spacing: int(app.spacing)
					content: [
						color_swatch('Background', bg_color, text_style, app),
						color_swatch('Panel', panel_color, text_style, app),
						color_swatch('Text', text_color, text_style, app),
						color_swatch('Accent', accent_color, text_style, app),
						color_swatch('Border', border_color, text_style, app),
					]
				),
			]),
			preview_section('Typography', text_style, panel_color, border_color, app,
				[
				typography_preview(app, text_color),
			]),
			gui.row(sizing: gui.fill_fit, height: bottom_padding_height),
		]
	)
}

fn preview_button(label string, id u32, color gui.Color, border_color gui.Color, text_style gui.TextStyle, app &ThemeEditorState, disabled bool) gui.View {
	return gui.button(
		id_focus:     id
		color:        color
		color_border: border_color
		size_border:  app.border_size
		radius:       app.border_radius
		disabled:     disabled
		content:      [gui.text(text: label, text_style: text_style)]
	)
}

fn preview_input(id u32, is_password bool, color gui.Color, border_color gui.Color, text_style gui.TextStyle, app &ThemeEditorState) gui.View {
	return gui.input(
		id_focus:        id
		width:           input_width
		sizing:          gui.fixed_fit
		text:            app.input_text
		is_password:     is_password
		color:           color
		color_border:    border_color
		size_border:     app.border_size
		radius:          app.border_radius
		text_style:      text_style
		on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
			mut state := w.state[ThemeEditorState]()
			state.input_text = s
		}
	)
}

fn typography_preview(app &ThemeEditorState, text_color gui.Color) gui.View {
	font := get_font_family(app)
	return gui.column(
		spacing: int(app.spacing)
		padding: gui.padding_none
		content: [
			gui.text(
				text:       'Heading 1'
				text_style: gui.TextStyle{
					family: font
					color:  text_color
					size:   app.font_size + heading1_size_offset
				}
			),
			gui.text(
				text:       'Heading 2'
				text_style: gui.TextStyle{
					family: font
					color:  text_color
					size:   app.font_size + heading2_size_offset
				}
			),
			gui.text(text: 'Body text in the selected font', text_style: get_text_style(app)),
			gui.text(
				text:       'Secondary text (muted)'
				text_style: gui.TextStyle{
					family: font
					color:  gui.rgba(u8(app.text_r), u8(app.text_g), u8(app.text_b), muted_alpha)
					size:   app.font_size + secondary_size_offset
				}
			),
			gui.text(
				text:       'Family: ${app.font_family} | Size: ${int(app.font_size)}px'
				text_style: gui.TextStyle{
					family: 'Menlo, Monaco, Mono'
					color:  gui.rgba(u8(app.text_r), u8(app.text_g), u8(app.text_b), subtle_alpha)
					size:   font_info_size
				}
			),
		]
	)
}

fn preview_section_title(title string, text_color gui.Color, border_color gui.Color) gui.View {
	return gui.column(
		sizing:  gui.fill_fit
		spacing: row_spacing
		padding: gui.padding(15, 15, 0, 15)
		content: [
			gui.text(
				text:       title
				text_style: gui.TextStyle{
					...gui.theme().b1
					color: text_color
				}
			),
			gui.row(
				height:  row_spacing
				sizing:  gui.fill_fit
				padding: gui.padding_none
				color:   border_color
			),
		]
	)
}

fn preview_section(title string, text_style gui.TextStyle, panel_color gui.Color, border_color gui.Color, app &ThemeEditorState, content []gui.View) gui.View {
	mut section_content := []gui.View{cap: content.len + 1}
	section_content << gui.text(
		text:       title
		text_style: gui.TextStyle{
			...gui.theme().b3
			color: text_style.color
		}
	)
	section_content << content
	return gui.column(
		sizing:       gui.fill_fit
		spacing:      int(app.spacing)
		padding:      gui.padding_medium
		color:        panel_color
		color_border: border_color
		size_border:  app.border_size
		radius:       app.border_radius
		shadow:       get_box_shadow(app)
		gradient:     get_gradient(app)
		content:      section_content
	)
}

fn color_swatch(label string, color gui.Color, text_style gui.TextStyle, app &ThemeEditorState) gui.View {
	return gui.column(
		h_align: .center
		spacing: gui.spacing_small
		padding: gui.padding_none
		content: [
			gui.row(
				width:        palette_swatch_size
				height:       palette_swatch_size
				sizing:       gui.fixed_fixed
				color:        color
				color_border: gui.theme().color_border
				size_border:  1
				radius:       app.border_radius
			),
			gui.text(
				text:       label
				text_style: gui.TextStyle{
					...label_style()
					color: text_style.color
				}
			),
		]
	)
}
