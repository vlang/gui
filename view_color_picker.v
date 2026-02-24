module gui

// view_color_picker.v implements a color picker component
// with SV area, hue slider, alpha slider, hex input, and
// RGBA numeric inputs.

// ColorPickerCfg configures the color picker component.
@[minify]
pub struct ColorPickerCfg {
	A11yCfg
pub:
	id              string @[required]
	color           Color = red
	on_color_change fn (Color, mut Event, mut Window) @[required]
	style           ColorPickerStyle = gui_theme.color_picker_style
	id_focus        u32
	show_hsv        bool
	sizing          Sizing
	width           f32
	height          f32
}

// color_picker creates a color picker View.
pub fn color_picker(cfg ColorPickerCfg) View {
	sv_size := cfg.style.sv_size
	slider_h := cfg.style.slider_height

	mut content := [
		// SV area + hue slider side by side
		row(
			padding: padding_none
			spacing: cfg.style.padding.left
			content: [
				cp_sv_area(cfg, sv_size),
				cp_hue_slider(cfg, slider_h, sv_size),
			]
		),
		cp_alpha_slider(cfg),
		cp_preview_row(cfg),
		cp_rgba_inputs(cfg),
	]
	if cfg.show_hsv {
		content << cp_hsv_inputs(cfg)
	}

	id := cfg.id
	color := cfg.color
	return column(
		name:             'color_picker'
		id:               cfg.id
		a11y_role:        .color_well
		a11y_label:       a11y_label(cfg.a11y_label, cfg.id)
		a11y_description: cfg.a11y_description
		a11y:             &AccessInfo{
			value_text: cfg.color.to_hex_string()
		}
		padding:          cfg.style.padding
		spacing:          cfg.style.padding.top
		color:            cfg.style.color
		radius:           cfg.style.radius
		content:          content
		amend_layout:     fn [id, color] (mut layout Layout, mut w Window) {
			// Initialize state from color if not already present
			mut cps := state_map[string, ColorPickerState](mut w, ns_color_picker, cap_few)
			if !cps.contains(id) {
				h, s, v := color.to_hsv()
				cps.set(id, ColorPickerState{h, s, v})
			}
		}
	)
}

// cp_sv_area renders the saturation-value gradient area.
fn cp_sv_area(cfg ColorPickerCfg, size f32) View {
	id := cfg.id
	color := cfg.color
	on_color_change := cfg.on_color_change
	indicator_size := cfg.style.indicator_size
	radius := cfg.style.radius

	return container(
		name:         'sv_area'
		id:           '${id}_sv'
		width:        size
		height:       size
		padding:      padding_none
		radius:       radius
		clip:         true
		amend_layout: fn [id, color] (mut layout Layout, mut w Window) {
			state := state_map[string, ColorPickerState](mut w, ns_color_picker, cap_few).get(id) or {
				h, s, v := color.to_hsv()
				ColorPickerState{h, s, v}
			}
			pure := hue_color(state.h)
			if layout.shape.fx == unsafe { nil } {
				layout.shape.fx = &ShapeEffects{}
			}
			layout.shape.fx.gradient = &Gradient{
				stops:     [
					GradientStop{
						color: white
						pos:   0
					},
					GradientStop{
						color: pure
						pos:   1.0
					},
				]
				direction: .to_right
			}
		}
		on_click:     fn [id, color, on_color_change] (layout &Layout, mut e Event, mut w Window) {
			w.mouse_lock(MouseLockCfg{
				mouse_move: fn [id, color, on_color_change] (layout &Layout, mut e Event, mut w Window) {
					sv := layout.find_layout(fn [id] (n Layout) bool {
						return n.shape.id == '${id}_sv'
					})
					if sv != none {
						cp_sv_mouse_move(id, color, on_color_change, &sv, mut e, mut w)
					}
				}
				mouse_up:   fn (_ &Layout, mut _ Event, mut w Window) {
					w.mouse_unlock()
					w.set_mouse_cursor_arrow()
				}
			})
			e.is_handled = true
		}
		content:      [
			// Vertical transparent-to-black overlay
			container(
				name:     'sv_overlay'
				sizing:   fill_fill
				padding:  padding_none
				gradient: &Gradient{
					stops:     [
						GradientStop{
							color: color_transparent
							pos:   0
						},
						GradientStop{
							color: black
							pos:   1.0
						},
					]
					direction: .to_bottom
				}
				content:  [
					// SV indicator circle
					circle(
						name:         'sv_indicator'
						width:        indicator_size
						height:       indicator_size
						color:        color.with_opacity(0.5)
						color_border: white
						size_border:  3
						padding:      padding_none
						amend_layout: fn [id, color, indicator_size] (mut layout Layout, mut w Window) {
							cp_amend_sv_indicator(id, color, indicator_size, mut layout, mut
								w)
						}
					),
				]
			),
		]
	)
}

// cp_hue_slider renders a vertical rainbow hue bar.
fn cp_hue_slider(cfg ColorPickerCfg, w f32, h f32) View {
	id := cfg.id
	color := cfg.color
	on_color_change := cfg.on_color_change
	indicator_size := cfg.style.indicator_size
	return container(
		name:     'hue_slider'
		id:       '${id}_hue'
		width:    w
		height:   h
		padding:  padding_none
		radius:   cfg.style.radius
		clip:     true
		gradient: &Gradient{
			stops:     [
				GradientStop{
					color: hue_color(0)
					pos:   0
				},
				GradientStop{
					color: hue_color(90)
					pos:   0.25
				},
				GradientStop{
					color: hue_color(180)
					pos:   0.5
				},
				GradientStop{
					color: hue_color(270)
					pos:   0.75
				},
				GradientStop{
					color: hue_color(360)
					pos:   1.0
				},
			]
			direction: .to_bottom
		}
		on_click: fn [id, color, on_color_change] (layout &Layout, mut e Event, mut w Window) {
			w.mouse_lock(MouseLockCfg{
				mouse_move: fn [id, color, on_color_change] (layout &Layout, mut e Event, mut w Window) {
					hue := layout.find_layout(fn [id] (n Layout) bool {
						return n.shape.id == '${id}_hue'
					})
					if hue != none {
						cp_hue_mouse_move(id, color, on_color_change, &hue, mut e, mut
							w)
					}
				}
				mouse_up:   fn (_ &Layout, mut _ Event, mut w Window) {
					w.mouse_unlock()
				}
			})
			e.is_handled = true
		}
		content:  [
			// Hue indicator circle
			circle(
				name:         'hue_indicator'
				width:        indicator_size
				height:       indicator_size
				color:        cfg.style.color // Temporary, fixed in amend
				color_border: white
				size_border:  3
				padding:      padding_none
				amend_layout: fn [id, color, indicator_size] (mut layout Layout, mut w Window) {
					cp_amend_hue_indicator(id, color, indicator_size, mut layout, mut
						w)
				}
			),
		]
	)
}

// cp_alpha_slider renders an alpha range slider (0-255).
fn cp_alpha_slider(cfg ColorPickerCfg) View {
	id := cfg.id
	color := cfg.color
	on_color_change := cfg.on_color_change

	return row(
		padding: padding(0, 5, 0, 5)
		sizing:  fill_fit
		content: [
			range_slider(
				id:        '${id}_alpha'
				sizing:    fill_fit
				value:     f32(color.a)
				min:       0
				max:       255
				on_change: fn [id, color, on_color_change] (value f32, mut e Event, mut w Window) {
					c := Color{
						r: color.r
						g: color.g
						b: color.b
						a: u8(value)
					}
					on_color_change(c, mut e, mut w)
					// Update persistent HSV state
					al_h, al_s, al_v := c.to_hsv()
					mut cps := state_map[string, ColorPickerState](mut w, ns_color_picker,
						cap_few)
					cps.set(id, ColorPickerState{al_h, al_s, al_v})
				}
			),
		]
	)
}

// cp_preview_row shows the current color swatch and hex input.
fn cp_preview_row(cfg ColorPickerCfg) View {
	id := cfg.id
	color := cfg.color
	on_color_change := cfg.on_color_change
	hex_str := color.to_hex_string()

	return row(
		name:    'preview_row'
		padding: padding_none
		spacing: cfg.style.padding.left
		sizing:  fill_fit
		v_align: .middle
		content: [
			rectangle(
				width:        32
				height:       32
				color:        color
				color_border: cfg.style.color_border
				size_border:  cfg.style.size_border
				radius:       cfg.style.radius
			),
			input(
				id:              '${id}_hex'
				id_focus:        cp_id_focus_base(cfg)
				text:            hex_str
				min_width:       100
				max_width:       100
				padding:         padding_small
				text_style:      cfg.style.text_style
				on_text_changed: fn [id, on_color_change] (_ &Layout, s string, mut w Window) {
					if c := color_from_hex_string(s) {
						mut ev := Event{}
						on_color_change(c, mut ev, mut w)
						// Update persistent HSV state
						h, hs, hv := c.to_hsv()
						mut cps := state_map[string, ColorPickerState](mut w, ns_color_picker,
							cap_few)
						cps.set(id, ColorPickerState{h, hs, hv})
					}
				}
			),
			row(
				v_align: .middle
				padding: padding_none
				spacing: 5
				content: [
					text(text: 'A', text_style: cfg.style.text_style),
					cp_channel_input(cfg, 'a', color.a, cp_id_focus_base(cfg) + 4),
				]
			),
		]
	)
}

// cp_rgba_inputs renders R, G, B, A numeric input fields.
fn cp_rgba_inputs(cfg ColorPickerCfg) View {
	return row(
		name:    'rgba_inputs'
		padding: padding_none
		spacing: 8
		v_align: .middle
		content: [
			row(
				padding: padding_none
				v_align: .middle
				spacing: 5
				content: [
					text(text: 'R', text_style: cfg.style.text_style),
					cp_channel_input(cfg, 'r', cfg.color.r, cp_id_focus_base(cfg) + 1),
				]
			),
			row(
				padding: padding_none
				v_align: .middle
				spacing: 5
				content: [
					text(text: 'G', text_style: cfg.style.text_style),
					cp_channel_input(cfg, 'g', cfg.color.g, cp_id_focus_base(cfg) + 2),
				]
			),
			row(
				padding: padding_none
				v_align: .middle
				spacing: 5
				content: [
					text(text: 'B', text_style: cfg.style.text_style),
					cp_channel_input(cfg, 'b', cfg.color.b, cp_id_focus_base(cfg) + 3),
				]
			),
		]
	)
}

// cp_channel_input creates a single numeric input for a color
// channel. Values are clamped to 0-255; non-numeric input
// is ignored. Always fires on_color_change to keep the
// input text and cursor in sync with the rendered value.
fn cp_channel_input(cfg ColorPickerCfg, ch string, val u8, id_focus u32) View {
	id := cfg.id
	color := cfg.color
	on_color_change := cfg.on_color_change
	w := f32(45) + cfg.style.size_border * 2

	return input(
		id:              '${id}_${ch}'
		id_focus:        id_focus
		text:            val.str()
		min_width:       w
		max_width:       w
		padding:         padding_small
		text_style:      cfg.style.text_style
		on_text_changed: fn [id, color, on_color_change, ch, val] (_ &Layout, s string, mut w Window) {
			mut nv := val
			if s.len > 0 {
				mut valid := true
				for b in s {
					if b < `0` || b > `9` {
						valid = false
						break
					}
				}
				if valid {
					mut n := s.int()
					if n > 255 {
						n = 255
					}
					nv = u8(n)
				}
			}
			clr := match ch {
				'r' {
					Color{
						r: nv
						g: color.g
						b: color.b
						a: color.a
					}
				}
				'g' {
					Color{
						r: color.r
						g: nv
						b: color.b
						a: color.a
					}
				}
				'b' {
					Color{
						r: color.r
						g: color.g
						b: nv
						a: color.a
					}
				}
				'a' {
					Color{
						r: color.r
						g: color.g
						b: color.b
						a: nv
					}
				}
				else {
					color
				}
			}
			mut ev := Event{}
			on_color_change(clr, mut ev, mut w)
			// Update persistent HSV state
			ch_h, ch_s, ch_v := clr.to_hsv()
			mut cps := state_map[string, ColorPickerState](mut w, ns_color_picker, cap_few)
			cps.set(id, ColorPickerState{ch_h, ch_s, ch_v})
		}
	)
}

// cp_hsv_inputs renders H, S, V numeric input fields.
fn cp_hsv_inputs(cfg ColorPickerCfg) View {
	ch, cs, cv := cfg.color.to_hsv()
	h_val := int(ch + 0.5)
	s_val := int(cs * 100.0 + 0.5)
	v_val := int(cv * 100.0 + 0.5)

	return row(
		name:    'hsv_inputs'
		padding: padding_none
		spacing: 8
		v_align: .middle
		content: [
			row(
				padding: padding_none
				v_align: .middle
				spacing: 5
				content: [
					text(text: 'H', text_style: cfg.style.text_style),
					cp_hsv_channel_input(cfg, 'h', h_val, 360, cp_id_focus_base(cfg) + 5),
				]
			),
			row(
				padding: padding_none
				v_align: .middle
				spacing: 5
				content: [
					text(text: 'S', text_style: cfg.style.text_style),
					cp_hsv_channel_input(cfg, 's', s_val, 100, cp_id_focus_base(cfg) + 6),
				]
			),
			row(
				padding: padding_none
				v_align: .middle
				spacing: 5
				content: [
					text(text: 'V', text_style: cfg.style.text_style),
					cp_hsv_channel_input(cfg, 'v', v_val, 100, cp_id_focus_base(cfg) + 7),
				]
			),
		]
	)
}

// cp_hsv_channel_input creates a numeric input for an HSV
// channel. H: 0-360 degrees, S/V: 0-100 percent.
fn cp_hsv_channel_input(cfg ColorPickerCfg, ch string, val int, max_val int, id_focus u32) View {
	id := cfg.id
	on_color_change := cfg.on_color_change
	color := cfg.color
	w := f32(45) + cfg.style.size_border * 2

	return input(
		id:              '${id}_hsv_${ch}'
		id_focus:        id_focus
		text:            val.str()
		min_width:       w
		max_width:       w
		padding:         padding_small
		text_style:      cfg.style.text_style
		on_text_changed: fn [id, ch, max_val, on_color_change, color] (_ &Layout, s string, mut w Window) {
			mut n := 0
			if s.len > 0 {
				mut valid := true
				for b in s {
					if b < `0` || b > `9` {
						valid = false
						break
					}
				}
				if valid {
					n = s.int()
					if n > max_val {
						n = max_val
					}
				}
			}
			mut cps := state_map[string, ColorPickerState](mut w, ns_color_picker, cap_few)
			state := cps.get(id) or {
				h, sv_s, sv_v := color.to_hsv()
				ColorPickerState{h, sv_s, sv_v}
			}
			new_h := if ch == 'h' { f32(n) } else { state.h }
			new_s := if ch == 's' { f32(n) / 100.0 } else { state.s }
			new_v := if ch == 'v' { f32(n) / 100.0 } else { state.v }
			cps.set(id, ColorPickerState{new_h, new_s, new_v})
			clr := color_from_hsva(new_h, new_s, new_v, color.a)
			mut ev := Event{}
			on_color_change(clr, mut ev, mut w)
		}
	)
}

// cp_id_focus_base returns the starting id_focus for picker
// sub-inputs, defaulting to a high value to avoid clashes.
fn cp_id_focus_base(cfg ColorPickerCfg) u32 {
	if cfg.id_focus > 0 {
		return cfg.id_focus
	}
	return 9000
}

// --- Mouse interaction helpers ---

// cp_sv_mouse_move handles mouse movement within the SV area.
fn cp_sv_mouse_move(id string, color Color, on_color_change fn (Color, mut Event, mut Window), layout &Layout, mut e Event, mut w Window) {
	shape := layout.shape
	s := f32_clamp((e.mouse_x - shape.x) / shape.width, 0, 1.0)
	v := 1.0 - f32_clamp((e.mouse_y - shape.y) / shape.height, 0, 1.0)
	mut cps := state_map[string, ColorPickerState](mut w, ns_color_picker, cap_few)
	state := cps.get(id) or {
		h, _, _ := color.to_hsv()
		ColorPickerState{h, s, v}
	}
	cps.set(id, ColorPickerState{state.h, s, v})
	c := color_from_hsva(state.h, s, v, color.a)
	on_color_change(c, mut e, mut w)
}

// cp_hue_mouse_move handles mouse movement within the hue slider.
fn cp_hue_mouse_move(id string, color Color, on_color_change fn (Color, mut Event, mut Window), layout &Layout, mut e Event, mut w Window) {
	shape := layout.shape
	percent := f32_clamp((e.mouse_y - shape.y) / shape.height, 0, 0.999)
	h := percent * 360.0
	mut cps := state_map[string, ColorPickerState](mut w, ns_color_picker, cap_few)
	state := cps.get(id) or {
		_, s, v := color.to_hsv()
		ColorPickerState{h, s, v}
	}
	cps.set(id, ColorPickerState{h, state.s, state.v})
	c := color_from_hsva(h, state.s, state.v, color.a)
	on_color_change(c, mut e, mut w)
}

// --- Layout amendment helpers ---

// cp_amend_sv_indicator positions the crosshair circle in the SV area.
fn cp_amend_sv_indicator(id string, color Color, indicator_size f32, mut layout Layout, mut w Window) {
	parent := layout.parent
	if parent == unsafe { nil } {
		return
	}
	// parent is the sv_overlay; grandparent is the sv_area
	gp := parent.parent
	if gp == unsafe { nil } {
		return
	}
	state := state_map[string, ColorPickerState](mut w, ns_color_picker, cap_few).get(id) or {
		h, s, v := color.to_hsv()
		ColorPickerState{h, s, v}
	}
	layout.shape.color = color.with_opacity(0.5)
	radius := indicator_size / 2.0
	layout.shape.x = gp.shape.x + (state.s * gp.shape.width) - radius
	layout.shape.y = gp.shape.y + ((1.0 - state.v) * gp.shape.height) - radius
}

// cp_amend_hue_indicator positions the hue indicator circle.
fn cp_amend_hue_indicator(id string, color Color, indicator_size f32, mut layout Layout, mut w Window) {
	parent := layout.parent
	if parent == unsafe { nil } {
		return
	}
	state := state_map[string, ColorPickerState](mut w, ns_color_picker, cap_few).get(id) or {
		h, s, v := color.to_hsv()
		ColorPickerState{h, s, v}
	}
	layout.shape.color = hue_color(state.h).with_opacity(0.5)
	percent := state.h / 360.0
	radius := indicator_size / 2.0
	layout.shape.y = parent.shape.y + (percent * parent.shape.height) - radius
	layout.shape.x = parent.shape.x + (parent.shape.width / 2.0) - radius
}
