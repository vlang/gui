import gui

// Theme Designer — Interactive theme editor with live preview.
// Left: tabbed editor (colors, style, effects, typography)
// Right: mini-app mockup preview

// Layout constants
const window_width = 1100
const window_height = 700
const editor_max_width = 340
const row_spacing = 2
const button_spacing = 3
const section_padding = 8
const slider_value_gap = 3
const cp_sv_size = f32(180)

// Swatch/preview sizes
const swatch_w = 40
const swatch_h = 24
const shadow_preview_width = 60
const shadow_preview_height = 30
const gradient_preview_width = 50
const gradient_preview_height = 20
const grad_swatch_width = 16
const grad_swatch_height = 14
const palette_swatch_size = 30
const input_width = 160
const progress_height = 20

// Label/value widths
const label_width_medium = 50
const label_width_gradient = 18
const label_width_stop = 10
const value_width_medium = 25
const value_width_large = 28

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
const muted_alpha = u8(180)

// Scroll IDs
const id_scroll_editor = 1
const id_scroll_preview = 2

// Focus IDs — base+offset blocks
const id_focus_tabs = u32(5)
const id_focus_preset_base = u32(10) // 10-14
const id_focus_style_base = u32(20) // 20-22
const id_focus_shadow_base = u32(30) // 30-34
const id_focus_grad_base = u32(40) // 40-54
const id_focus_font_base = u32(60) // 60-63
const id_focus_preview_tabs = u32(200)
const id_focus_preview_base = u32(210) // 210+

@[heap]
struct ThemeEditorState {
pub mut:
	selected_tab   string = 'colors'
	selected_color string = 'bg'
	preset_gen     int // bumped on preset/load to reset picker state
	// Colors
	bg_color     gui.Color = gui.rgb(48, 48, 48)
	panel_color  gui.Color = gui.rgb(64, 64, 64)
	text_color   gui.Color = gui.rgb(225, 225, 225)
	accent_color gui.Color = gui.rgb(65, 105, 225)
	border_color gui.Color = gui.rgb(100, 100, 100)
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
	gradient_enabled   bool
	gradient_type      string                = 'Linear'
	gradient_direction gui.GradientDirection = .to_bottom
	grad_stop1_pos     f32
	grad_stop1_r       f32 = 100
	grad_stop1_g       f32 = 100
	grad_stop1_b       f32 = 200
	grad_stop2_pos     f32 = 1.0
	grad_stop2_r       f32 = 50
	grad_stop2_g       f32 = 50
	grad_stop2_b       f32 = 100
	// Preview state
	preview_tab  string = 'controls'
	input_name   string = 'John Doe'
	input_email  string = 'john@example.com'
	notif_on     bool   = true
	autosave_on  bool
	slider_value f32 = 50
	storage_pct  f32 = 0.65
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
// Helpers
// ============================================================

fn label_style() gui.TextStyle {
	return gui.theme().n5
}

fn get_selected_color(app &ThemeEditorState) gui.Color {
	return match app.selected_color {
		'bg' { app.bg_color }
		'panel' { app.panel_color }
		'text' { app.text_color }
		'accent' { app.accent_color }
		'border' { app.border_color }
		else { app.bg_color }
	}
}

fn set_selected_color(mut app ThemeEditorState, sel string, c gui.Color) {
	match sel {
		'bg' { app.bg_color = c }
		'panel' { app.panel_color = c }
		'text' { app.text_color = c }
		'accent' { app.accent_color = c }
		'border' { app.border_color = c }
		else {}
	}
}

fn lighten(c gui.Color, amount u8) gui.Color {
	r := if c.r > 255 - amount { u8(255) } else { c.r + amount }
	g := if c.g > 255 - amount { u8(255) } else { c.g + amount }
	b := if c.b > 255 - amount { u8(255) } else { c.b + amount }
	return gui.rgba(r, g, b, c.a)
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
		color:  app.text_color
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
		type:      if app.gradient_type == 'Radial' { .radial } else { .linear }
		direction: app.gradient_direction
		stops:     [
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

// ============================================================
// Theme Building
// ============================================================

fn build_theme_from_state(app &ThemeEditorState) gui.Theme {
	panel := app.panel_color
	return gui.theme_maker(&gui.ThemeCfg{
		name:               'custom'
		color_background:   app.bg_color
		color_panel:        panel
		color_interior:     lighten(panel, 10)
		color_hover:        lighten(panel, 20)
		color_focus:        lighten(panel, 30)
		color_active:       lighten(panel, 40)
		color_border:       app.border_color
		color_border_focus: app.accent_color
		color_select:       app.accent_color
		size_border:        app.border_size
		radius:             app.border_radius
		text_style:         gui.TextStyle{
			family: get_font_family(app)
			color:  app.text_color
			size:   app.font_size
		}
	})
}

fn apply_theme_to_state(theme gui.Theme, mut app ThemeEditorState) {
	app.bg_color = theme.color_background
	app.panel_color = theme.color_panel
	app.text_color = theme.n1.color
	app.accent_color = theme.color_select
	app.border_color = theme.color_border
	app.border_size = theme.button_style.size_border
	app.border_radius = theme.button_style.radius
}

fn apply_preset(preset_name string, mut w gui.Window) {
	theme := match preset_name {
		'Dark' { gui.theme_dark }
		'Light' { gui.theme_light }
		'Dark Bordered' { gui.theme_dark_bordered }
		'Light Bordered' { gui.theme_light_bordered }
		'Blue Bordered' { gui.theme_blue_bordered }
		else { gui.theme_dark_bordered }
	}
	w.set_theme(theme)
	mut app := w.state[ThemeEditorState]()
	apply_theme_to_state(theme, mut app)
	app.preset_gen++
}

// ============================================================
// Editor Panel (Left)
// ============================================================

fn editor_panel(window &gui.Window) gui.View {
	app := window.state[ThemeEditorState]()
	return gui.column(
		sizing:    gui.fill_fill
		max_width: editor_max_width
		color:     gui.theme().color_panel
		spacing:   gui.spacing_small
		content:   [
			toolbar(),
			gui.tab_control(
				id:        'editor_tabs'
				id_focus:  id_focus_tabs
				selected:  app.selected_tab
				sizing:    gui.fill_fill
				items:     [
					gui.tab_item('colors', 'Colors', colors_content(window)),
					gui.tab_item('style', 'Style', style_content(window)),
					gui.tab_item('effects', 'Effects', effects_content(window)),
					gui.tab_item('type', 'Type', type_content(window)),
				]
				on_select: fn (id string, mut _ gui.Event, mut w gui.Window) {
					mut state := w.state[ThemeEditorState]()
					state.selected_tab = id
				}
			),
		]
	)
}

fn toolbar() gui.View {
	return gui.row(
		sizing:  gui.fill_fit
		padding: gui.padding_small
		spacing: button_spacing
		v_align: .middle
		content: [
			preset_button('Drk', 'Dark', id_focus_preset_base),
			preset_button('Lgt', 'Light', id_focus_preset_base + 1),
			preset_button('D+B', 'Dark Bordered', id_focus_preset_base + 2),
			preset_button('L+B', 'Light Bordered', id_focus_preset_base + 3),
			preset_button('Blu', 'Blue Bordered', id_focus_preset_base + 4),
			gui.row(sizing: gui.fill_fit),
			load_button(),
			save_button(),
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

fn load_button() gui.View {
	return gui.button(
		padding:      gui.padding(2, 5, 2, 5)
		color:        gui.theme().color_interior
		color_border: gui.theme().color_border
		size_border:  1
		radius:       gui.radius_small
		content:      [gui.text(text: 'Load', text_style: label_style())]
		on_click:     fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			w.native_open_dialog(gui.NativeOpenDialogCfg{
				title:   'Load Theme'
				filters: [
					gui.NativeFileFilter{
						name:       'JSON'
						extensions: ['json']
					},
				]
				on_done: fn (result gui.NativeDialogResult, mut w gui.Window) {
					if result.status != .ok || result.paths.len == 0 {
						return
					}
					theme := gui.theme_load(result.paths[0]) or { return }
					mut app := w.state[ThemeEditorState]()
					apply_theme_to_state(theme, mut app)
					app.preset_gen++
					w.set_theme(theme)
				}
			})
		}
	)
}

fn save_button() gui.View {
	return gui.button(
		padding:      gui.padding(2, 5, 2, 5)
		color:        gui.theme().color_interior
		color_border: gui.theme().color_border
		size_border:  1
		radius:       gui.radius_small
		content:      [gui.text(text: 'Save', text_style: label_style())]
		on_click:     fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			w.native_save_dialog(gui.NativeSaveDialogCfg{
				title:             'Save Theme'
				default_name:      'theme.json'
				default_extension: 'json'
				filters:           [
					gui.NativeFileFilter{
						name:       'JSON'
						extensions: ['json']
					},
				]
				on_done:           fn (result gui.NativeDialogResult, mut w gui.Window) {
					if result.status != .ok || result.paths.len == 0 {
						return
					}
					app := w.state[ThemeEditorState]()
					theme := build_theme_from_state(app)
					gui.theme_save(result.paths[0], theme) or {}
				}
			})
		}
	)
}

// ============================================================
// Colors Tab
// ============================================================

fn colors_content(window &gui.Window) []gui.View {
	app := window.state[ThemeEditorState]()
	sel := app.selected_color
	gen := app.preset_gen
	color := get_selected_color(app)
	return [
		swatch_row(app),
		gui.color_picker(
			id:              'theme_cp_${sel}_${gen}'
			color:           color
			style:           gui.ColorPickerStyle{
				...gui.theme().color_picker_style
				sv_size: cp_sv_size
			}
			on_color_change: fn [sel] (c gui.Color, mut _ gui.Event, mut w gui.Window) {
				mut state := w.state[ThemeEditorState]()
				set_selected_color(mut state, sel, c)
			}
		),
	]
}

fn swatch_row(app &ThemeEditorState) gui.View {
	sel := app.selected_color
	return gui.row(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		spacing: button_spacing
		h_align: .center
		content: [
			swatch_button('Bg', 'bg', app.bg_color, sel),
			swatch_button('Pnl', 'panel', app.panel_color, sel),
			swatch_button('Txt', 'text', app.text_color, sel),
			swatch_button('Acc', 'accent', app.accent_color, sel),
			swatch_button('Brd', 'border', app.border_color, sel),
		]
	)
}

fn swatch_button(label string, swatch_name string, color gui.Color, selected string) gui.View {
	is_selected := swatch_name == selected
	return gui.column(
		h_align: .center
		spacing: 2
		padding: gui.padding_none
		content: [
			gui.button(
				width:        swatch_w
				height:       swatch_h
				sizing:       gui.fixed_fixed
				padding:      gui.padding_none
				color:        color
				color_border: if is_selected {
					gui.theme().color_select
				} else {
					gui.theme().color_border
				}
				size_border:  if is_selected { f32(2) } else { f32(1) }
				radius:       gui.radius_small
				on_click:     fn [swatch_name] (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					mut state := w.state[ThemeEditorState]()
					state.selected_color = swatch_name
				}
			),
			gui.text(text: label, text_style: label_style()),
		]
	)
}

// ============================================================
// Style Tab
// ============================================================

fn style_content(window &gui.Window) []gui.View {
	app := window.state[ThemeEditorState]()
	return [
		slider_row('Radius', app.border_radius, 0, radius_max, label_width_medium, value_width_medium,
			'style_radius', true, id_focus_style_base, 0, make_style_handler('radius')),
		slider_row('Border', app.border_size, 0, border_max, label_width_medium, value_width_medium,
			'style_border', true, id_focus_style_base + 1, 0, make_style_handler('border_size')),
		slider_row('Spacing', app.spacing, 0, spacing_max, label_width_medium, value_width_medium,
			'style_spacing', true, id_focus_style_base + 2, 0, make_style_handler('spacing')),
	]
}

fn make_style_handler(field string) fn (f32, mut gui.Event, mut gui.Window) {
	return fn [field] (value f32, mut _ gui.Event, mut w gui.Window) {
		mut app := w.state[ThemeEditorState]()
		match field {
			'radius' { app.border_radius = value }
			'border_size' { app.border_size = value }
			'spacing' { app.spacing = value }
			else {}
		}
	}
}

// ============================================================
// Effects Tab
// ============================================================

fn effects_content(window &gui.Window) []gui.View {
	app := window.state[ThemeEditorState]()
	return [
		section_title('Box Shadow'),
		shadow_sliders(app),
		shadow_preview(app),
		section_title('Gradient'),
		gradient_controls(app),
	]
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

fn shadow_sliders(app &ThemeEditorState) gui.View {
	return gui.column(
		sizing:  gui.fill_fit
		spacing: row_spacing
		padding: gui.padding_none
		content: [
			slider_row('Offset X', app.shadow_offset_x, shadow_offset_min, shadow_offset_max,
				label_width_medium, value_width_medium, 'shadow_offset_x', true, id_focus_shadow_base,
				0, make_shadow_handler('offset_x')),
			slider_row('Offset Y', app.shadow_offset_y, shadow_offset_min, shadow_offset_max,
				label_width_medium, value_width_medium, 'shadow_offset_y', true,
				id_focus_shadow_base + 1, 0, make_shadow_handler('offset_y')),
			slider_row('Blur', app.shadow_blur, 0, shadow_blur_max, label_width_medium,
				value_width_medium, 'shadow_blur', true, id_focus_shadow_base + 2, 0,
				make_shadow_handler('blur')),
			slider_row('Spread', app.shadow_spread, shadow_spread_min, shadow_spread_max,
				label_width_medium, value_width_medium, 'shadow_spread', true,
				id_focus_shadow_base + 3, 0, make_shadow_handler('spread')),
			slider_row('Opacity', app.shadow_alpha, 0, color_max, label_width_medium,
				value_width_medium, 'shadow_alpha', true, id_focus_shadow_base + 4, 0,
				make_shadow_handler('alpha')),
		]
	)
}

fn make_shadow_handler(field string) fn (f32, mut gui.Event, mut gui.Window) {
	return fn [field] (value f32, mut _ gui.Event, mut w gui.Window) {
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

fn gradient_controls(app &ThemeEditorState) gui.View {
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
						id_focus: id_focus_grad_base
						select:   app.gradient_enabled
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut state := w.state[ThemeEditorState]()
							state.gradient_enabled = !state.gradient_enabled
						}
					),
					grad_type_button('Lin', 'Linear', id_focus_grad_base + 1, app),
					grad_type_button('Rad', 'Radial', id_focus_grad_base + 2, app),
					gradient_preview(app),
				]
			),
			gui.row(
				sizing:  gui.fill_fit
				padding: gui.padding_none
				v_align: .middle
				spacing: gui.spacing_small
				content: [
					gui.text(text: 'Dir', min_width: label_width_gradient, text_style: label_style()),
					grad_dir_button('\u25B2', .to_top, id_focus_grad_base + 3, app),
					grad_dir_button('\u25B6', .to_right, id_focus_grad_base + 4, app),
					grad_dir_button('\u25BC', .to_bottom, id_focus_grad_base + 5, app),
					grad_dir_button('\u25C0', .to_left, id_focus_grad_base + 6, app),
				]
			),
			grad_stop_row('1', app.grad_stop1_r, app.grad_stop1_g, app.grad_stop1_b, app.grad_stop1_pos,
				'stop1', id_focus_grad_base + 7),
			grad_stop_row('2', app.grad_stop2_r, app.grad_stop2_g, app.grad_stop2_b, app.grad_stop2_pos,
				'stop2', id_focus_grad_base + 11),
		]
	)
}

fn grad_type_button(label string, type_name string, id_focus u32, app &ThemeEditorState) gui.View {
	return toggle_button(label, app.gradient_type == type_name, id_focus, fn [type_name] (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
		mut state := w.state[ThemeEditorState]()
		state.gradient_type = type_name
	})
}

fn grad_dir_button(label string, dir gui.GradientDirection, id_focus u32, app &ThemeEditorState) gui.View {
	return toggle_button(label, app.gradient_direction == dir, id_focus, fn [dir] (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
		mut state := w.state[ThemeEditorState]()
		state.gradient_direction = dir
	})
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
// Typography Tab
// ============================================================

fn type_content(window &gui.Window) []gui.View {
	app := window.state[ThemeEditorState]()
	return [
		gui.row(
			sizing:  gui.fill_fit
			padding: gui.padding_none
			v_align: .middle
			spacing: gui.spacing_small
			content: [
				gui.text(text: 'Family', min_width: 45),
				font_button('System', id_focus_font_base, app),
				font_button('Serif', id_focus_font_base + 1, app),
				font_button('Mono', id_focus_font_base + 2, app),
			]
		),
		slider_row('Size', app.font_size, font_size_min, font_size_max, 45, value_width_medium,
			'font_size', true, id_focus_font_base + 3, 0, fn (value f32, mut _ gui.Event, mut w gui.Window) {
			mut state := w.state[ThemeEditorState]()
			state.font_size = value
		}),
		typeface_preview(app),
	]
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

// ============================================================
// Preview Panel (Right) — Tabbed Widget Gallery
// ============================================================

fn preview_panel(window &gui.Window) gui.View {
	app := window.state[ThemeEditorState]()
	return gui.column(
		sizing:  gui.fill_fill
		color:   app.bg_color
		padding: gui.padding_small
		content: [
			gui.tab_control(
				id:        'preview_tabs'
				id_focus:  id_focus_preview_tabs
				selected:  app.preview_tab
				sizing:    gui.fill_fill
				items:     [
					gui.tab_item('controls', 'Controls', preview_controls(window)),
					gui.tab_item('inputs', 'Inputs', preview_inputs(window)),
					gui.tab_item('display', 'Display', preview_display(window)),
					gui.tab_item('type', 'Type', preview_type(window)),
				]
				on_select: fn (id string, mut _ gui.Event, mut w gui.Window) {
					mut state := w.state[ThemeEditorState]()
					state.preview_tab = id
				}
			),
		]
	)
}

// Controls tab — buttons, toggles, switches
fn preview_controls(window &gui.Window) []gui.View {
	app := window.state[ThemeEditorState]()
	text_style := get_text_style(app)
	return [
		preview_section('Buttons', text_style, app, [
			gui.row(
				spacing: int(app.spacing)
				content: [
					preview_btn('Primary', app.panel_color, app),
					preview_btn('Accent', app.accent_color, app),
					preview_btn('Disabled', app.panel_color, app),
				]
			),
		]),
		preview_section('Toggles', text_style, app, [
			gui.row(
				sizing:  gui.fill_fit
				v_align: .middle
				content: [
					gui.text(text: 'Notifications', text_style: text_style),
					gui.row(sizing: gui.fill_fit),
					gui.toggle(
						select:   app.notif_on
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut state := w.state[ThemeEditorState]()
							state.notif_on = !state.notif_on
						}
					),
				]
			),
		]),
		preview_section('Switches', text_style, app, [
			gui.row(
				sizing:  gui.fill_fit
				v_align: .middle
				content: [
					gui.text(text: 'Auto-save', text_style: text_style),
					gui.row(sizing: gui.fill_fit),
					gui.switch(
						select:   app.autosave_on
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut state := w.state[ThemeEditorState]()
							state.autosave_on = !state.autosave_on
						}
					),
				]
			),
		]),
	]
}

// Inputs tab — text inputs, sliders
fn preview_inputs(window &gui.Window) []gui.View {
	app := window.state[ThemeEditorState]()
	text_style := get_text_style(app)
	return [
		preview_section('Text Inputs', text_style, app, [
			labeled_input('Name', app.input_name, text_style, app, id_focus_preview_base,
				fn (_ &gui.Layout, s string, mut w gui.Window) {
				mut state := w.state[ThemeEditorState]()
				state.input_name = s
			}),
			labeled_input('Email', app.input_email, text_style, app, id_focus_preview_base + 1,
				fn (_ &gui.Layout, s string, mut w gui.Window) {
				mut state := w.state[ThemeEditorState]()
				state.input_email = s
			}),
		]),
		preview_section('Range Sliders', text_style, app, [
			gui.row(
				sizing:  gui.fill_fit
				v_align: .middle
				spacing: int(app.spacing)
				content: [
					gui.range_slider(
						id:           'preview_slider'
						value:        app.slider_value
						min:          0
						max:          slider_max
						round_value:  true
						sizing:       gui.fill_fit
						color:        app.panel_color
						color_border: app.border_color
						color_thumb:  app.accent_color
						color_left:   app.accent_color
						on_change:    fn (value f32, mut _ gui.Event, mut w gui.Window) {
							mut state := w.state[ThemeEditorState]()
							state.slider_value = value
						}
					),
					gui.text(
						text:       '${int(app.slider_value)}%'
						text_style: text_style
						min_width:  35
					),
				]
			),
		]),
	]
}

// Display tab — progress bars, color palette
fn preview_display(window &gui.Window) []gui.View {
	app := window.state[ThemeEditorState]()
	text_style := get_text_style(app)
	return [
		preview_section('Progress Bars', text_style, app, [
			gui.progress_bar(
				sizing:     gui.fill_fit
				height:     progress_height
				percent:    app.storage_pct
				color:      app.panel_color
				color_bar:  app.accent_color
				radius:     app.border_radius
				text_style: text_style
			),
			gui.progress_bar(
				sizing:    gui.fill_fit
				height:    8
				percent:   app.storage_pct
				color:     app.panel_color
				color_bar: app.accent_color
				radius:    app.border_radius
				text_show: false
			),
		]),
		preview_section('Color Palette', text_style, app, [
			gui.row(
				spacing: int(app.spacing)
				content: [
					color_swatch('Bg', app.bg_color, text_style, app),
					color_swatch('Panel', app.panel_color, text_style, app),
					color_swatch('Text', app.text_color, text_style, app),
					color_swatch('Accent', app.accent_color, text_style, app),
					color_swatch('Border', app.border_color, text_style, app),
				]
			),
		]),
	]
}

// Type tab — typography hierarchy
fn preview_type(window &gui.Window) []gui.View {
	app := window.state[ThemeEditorState]()
	text_style := get_text_style(app)
	return [
		preview_section('Typography', text_style, app, [
			typography_preview(app),
		]),
	]
}

// Preview helpers

fn preview_btn(label string, color gui.Color, app &ThemeEditorState) gui.View {
	return gui.button(
		color:        color
		color_border: app.border_color
		size_border:  app.border_size
		radius:       app.border_radius
		content:      [gui.text(text: label, text_style: get_text_style(app))]
	)
}

fn preview_section(title string, text_style gui.TextStyle, app &ThemeEditorState, content []gui.View) gui.View {
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
		color:        app.panel_color
		color_border: app.border_color
		size_border:  app.border_size
		radius:       app.border_radius
		shadow:       get_box_shadow(app)
		gradient:     get_gradient(app)
		content:      section_content
	)
}

fn labeled_input(label string, value string, text_style gui.TextStyle, app &ThemeEditorState, id_focus u32, on_text_changed fn (&gui.Layout, string, mut gui.Window)) gui.View {
	return gui.row(
		sizing:  gui.fill_fit
		v_align: .middle
		spacing: int(app.spacing)
		content: [
			gui.text(text: label, text_style: text_style, min_width: 45),
			gui.input(
				id_focus:        id_focus
				width:           input_width
				sizing:          gui.fixed_fit
				text:            value
				color:           lighten(app.panel_color, 10)
				color_border:    app.border_color
				size_border:     app.border_size
				radius:          app.border_radius
				text_style:      text_style
				on_text_changed: on_text_changed
			),
		]
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
				color_border: app.border_color
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

fn typography_preview(app &ThemeEditorState) gui.View {
	font := get_font_family(app)
	return gui.column(
		spacing: int(app.spacing)
		padding: gui.padding_none
		content: [
			gui.text(
				text:       'Heading 1'
				text_style: gui.TextStyle{
					family: font
					color:  app.text_color
					size:   app.font_size + heading1_size_offset
				}
			),
			gui.text(
				text:       'Heading 2'
				text_style: gui.TextStyle{
					family: font
					color:  app.text_color
					size:   app.font_size + heading2_size_offset
				}
			),
			gui.text(text: 'Body text paragraph', text_style: get_text_style(app)),
			gui.text(
				text:       'Secondary text (muted)'
				text_style: gui.TextStyle{
					family: font
					color:  gui.rgba(app.text_color.r, app.text_color.g, app.text_color.b,
						muted_alpha)
					size:   app.font_size + secondary_size_offset
				}
			),
		]
	)
}

// ============================================================
// Shared UI Helpers
// ============================================================

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
