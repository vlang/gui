module gui

// view_color_picker.v implements a color picker component
// with SV area, hue slider, alpha slider, hex input, and
// RGBA numeric inputs.

// ColorPickerCfg configures the color picker component.
@[heap; minify]
pub struct ColorPickerCfg {
pub:
	id              string @[required]
	color           Color = red
	on_color_change fn (Color, mut Event, mut Window) @[required]
	style           ColorPickerStyle = gui_theme.color_picker_style
	id_focus        u32
	sizing          Sizing
	width           f32
	height          f32
}

// color_picker creates a color picker View.
pub fn color_picker(cfg ColorPickerCfg) View {
	sv_size := cfg.style.sv_size
	slider_h := cfg.style.slider_height

	return column(
		name:    'color_picker_expanded'
		id:      cfg.id
		padding: cfg.style.padding
		spacing: cfg.style.padding.top
		color:   cfg.style.color
		radius:  cfg.style.radius
		content: [
			// SV area + hue slider side by side
			row(
				padding: padding_none
				spacing: cfg.style.padding.left
				content: [
					cfg.sv_area(sv_size),
					cfg.hue_slider(slider_h, sv_size),
				]
			),
			// Alpha slider
			cfg.alpha_slider(),
			// Preview + hex
			cfg.preview_row(),
			// RGBA inputs
			cfg.rgba_inputs(),
		]
	)
}

// sv_area renders the saturation-value gradient area.
fn (cfg &ColorPickerCfg) sv_area(size f32) View {
	h, _, _ := cfg.color.to_hsv()
	pure := hue_color(h)
	id := cfg.id

	return container(
		name:     'sv_area'
		id:       '${cfg.id}_sv'
		width:    size
		height:   size
		padding:  padding_none
		radius:   cfg.style.radius
		clip:     true
		gradient: &Gradient{
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
		on_click: fn [cfg, id] (layout &Layout, mut e Event, mut w Window) {
			cfg.sv_mouse_move(layout, mut e, mut w)
			w.mouse_lock(MouseLockCfg{
				mouse_move: fn [cfg, id] (layout &Layout, mut e Event, mut w Window) {
					sv := layout.find_layout(fn [id] (n Layout) bool {
						return n.shape.id == '${id}_sv'
					})
					if sv != none {
						cfg.sv_mouse_move(&sv, mut e, mut w)
					}
				}
				mouse_up:   fn (_ &Layout, mut _ Event, mut w Window) {
					w.mouse_unlock()
				}
			})
			e.is_handled = true
		}
		content:  [
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
						width:        cfg.style.indicator_size
						height:       cfg.style.indicator_size
						color:        cfg.color.with_opacity(0.5)
						color_border: white
						size_border:  2
						padding:      padding_none
						amend_layout: fn [cfg] (mut layout Layout, mut _ Window) {
							cfg.amend_sv_indicator(mut layout)
						}
					),
				]
			),
		]
	)
}

// hue_slider renders a vertical rainbow hue bar.
fn (cfg &ColorPickerCfg) hue_slider(w f32, h f32) View {
	id := cfg.id
	return container(
		name:     'hue_slider'
		id:       '${cfg.id}_hue'
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
					color: hue_color(60)
					pos:   0.167
				},
				GradientStop{
					color: hue_color(120)
					pos:   0.333
				},
				GradientStop{
					color: hue_color(180)
					pos:   0.5
				},
				GradientStop{
					color: hue_color(240)
					pos:   0.667
				},
				GradientStop{
					color: hue_color(300)
					pos:   0.833
				},
			]
			direction: .to_bottom
		}
		on_click: fn [cfg, id] (layout &Layout, mut e Event, mut w Window) {
			cfg.hue_mouse_move(layout, mut e, mut w)
			w.mouse_lock(MouseLockCfg{
				mouse_move: fn [cfg, id] (layout &Layout, mut e Event, mut w Window) {
					hue := layout.find_layout(fn [id] (n Layout) bool {
						return n.shape.id == '${id}_hue'
					})
					if hue != none {
						cfg.hue_mouse_move(&hue, mut e, mut w)
					}
				}
				mouse_up:   fn (_ &Layout, mut _ Event, mut w Window) {
					w.mouse_unlock()
				}
			})
			e.is_handled = true
		}
		content:  [
			// Hue indicator line
			container(
				name:         'hue_indicator'
				width:        w
				height:       3
				color:        white
				color_border: white
				size_border:  1
				padding:      padding_none
				amend_layout: fn [cfg] (mut layout Layout, mut _ Window) {
					cfg.amend_hue_indicator(mut layout)
				}
			),
		]
	)
}

// alpha_slider renders an alpha range slider (0-255).
fn (cfg &ColorPickerCfg) alpha_slider() View {
	return range_slider(
		id:        '${cfg.id}_alpha'
		sizing:    fill_fit
		value:     f32(cfg.color.a)
		min:       0
		max:       255
		on_change: fn [cfg] (value f32, mut e Event, mut w Window) {
			c := Color{
				r: cfg.color.r
				g: cfg.color.g
				b: cfg.color.b
				a: u8(value)
			}
			cfg.on_color_change(c, mut e, mut w)
		}
	)
}

// preview_row shows the current color swatch and hex input.
fn (cfg &ColorPickerCfg) preview_row() View {
	hex_str := cfg.color.to_hex_string()
	return row(
		name:    'preview_row'
		padding: padding_none
		spacing: cfg.style.padding.left
		v_align: .middle
		content: [
			rectangle(
				width:        32
				height:       32
				color:        cfg.color
				color_border: cfg.style.color_border
				size_border:  cfg.style.size_border
				radius:       cfg.style.radius
			),
			input(
				id:              '${cfg.id}_hex'
				id_focus:        cfg.id_focus_base()
				text:            hex_str
				min_width:       100
				max_width:       100
				text_style:      cfg.style.text_style
				on_text_changed: fn [cfg] (_ &Layout, s string, mut w Window) {
					if c := color_from_hex_string(s) {
						mut ev := Event{}
						cfg.on_color_change(c, mut ev, mut w)
					}
				}
			),
		]
	)
}

// rgba_inputs renders R, G, B, A numeric input fields.
fn (cfg &ColorPickerCfg) rgba_inputs() View {
	return column(
		name:    'rgba_inputs'
		padding: padding_none
		spacing: cfg.style.padding.top
		content: [
			row(
				padding: padding_none
				spacing: cfg.style.padding.left
				v_align: .middle
				content: [
					text(text: 'R', text_style: cfg.style.text_style),
					cfg.channel_input('r', cfg.color.r, cfg.id_focus_base() + 1),
					text(text: 'G', text_style: cfg.style.text_style),
					cfg.channel_input('g', cfg.color.g, cfg.id_focus_base() + 2),
				]
			),
			row(
				padding: padding_none
				spacing: cfg.style.padding.left
				v_align: .middle
				content: [
					text(text: 'B', text_style: cfg.style.text_style),
					cfg.channel_input('b', cfg.color.b, cfg.id_focus_base() + 3),
					text(text: 'A', text_style: cfg.style.text_style),
					cfg.channel_input('a', cfg.color.a, cfg.id_focus_base() + 4),
				]
			),
		]
	)
}

// channel_input creates a single numeric input for a color
// channel. Values are clamped to 0-255; non-numeric input
// is ignored. Always fires on_color_change to keep the
// input text and cursor in sync with the rendered value.
fn (cfg &ColorPickerCfg) channel_input(ch string, val u8, id_focus u32) View {
	return input(
		id:              '${cfg.id}_${ch}'
		id_focus:        id_focus
		text:            val.str()
		min_width:       55
		max_width:       55
		text_style:      cfg.style.text_style
		on_text_changed: fn [cfg, ch, val] (_ &Layout, s string, mut w Window) {
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
						g: cfg.color.g
						b: cfg.color.b
						a: cfg.color.a
					}
				}
				'g' {
					Color{
						r: cfg.color.r
						g: nv
						b: cfg.color.b
						a: cfg.color.a
					}
				}
				'b' {
					Color{
						r: cfg.color.r
						g: cfg.color.g
						b: nv
						a: cfg.color.a
					}
				}
				'a' {
					Color{
						r: cfg.color.r
						g: cfg.color.g
						b: cfg.color.b
						a: nv
					}
				}
				else {
					cfg.color
				}
			}
			mut ev := Event{}
			cfg.on_color_change(clr, mut ev, mut w)
		}
	)
}

// id_focus_base returns the starting id_focus for picker
// sub-inputs, defaulting to a high value to avoid clashes.
fn (cfg &ColorPickerCfg) id_focus_base() u32 {
	if cfg.id_focus > 0 {
		return cfg.id_focus
	}
	return 9000
}

// --- Mouse interaction helpers ---

// sv_mouse_move handles mouse movement within the SV area.
fn (cfg &ColorPickerCfg) sv_mouse_move(layout &Layout, mut e Event, mut w Window) {
	shape := layout.shape
	s := f32_clamp((e.mouse_x - shape.x) / shape.width, 0, 1)
	v := 1.0 - f32_clamp((e.mouse_y - shape.y) / shape.height, 0, 1)
	h, _, _ := cfg.color.to_hsv()
	c := color_from_hsva(h, s, v, cfg.color.a)
	cfg.on_color_change(c, mut e, mut w)
}

// hue_mouse_move handles mouse movement within the hue slider.
fn (cfg &ColorPickerCfg) hue_mouse_move(layout &Layout, mut e Event, mut w Window) {
	shape := layout.shape
	percent := f32_clamp((e.mouse_y - shape.y) / shape.height, 0, 1)
	h := percent * 360.0
	_, s, v := cfg.color.to_hsv()
	c := color_from_hsva(h, s, v, cfg.color.a)
	cfg.on_color_change(c, mut e, mut w)
}

// --- Layout amendment helpers ---

// amend_sv_indicator positions the crosshair circle in the SV area.
fn (cfg &ColorPickerCfg) amend_sv_indicator(mut layout Layout) {
	parent := layout.parent
	if parent == unsafe { nil } {
		return
	}
	// parent is the sv_overlay; grandparent is the sv_area
	gp := parent.parent
	if gp == unsafe { nil } {
		return
	}
	_, s, v := cfg.color.to_hsv()
	radius := cfg.style.indicator_size / 2.0
	layout.shape.x = gp.shape.x + (s * gp.shape.width) - radius
	layout.shape.y = gp.shape.y + ((1.0 - v) * gp.shape.height) - radius
}

// amend_hue_indicator positions the hue indicator line.
fn (cfg &ColorPickerCfg) amend_hue_indicator(mut layout Layout) {
	parent := layout.parent
	if parent == unsafe { nil } {
		return
	}
	h, _, _ := cfg.color.to_hsv()
	percent := h / 360.0
	layout.shape.y = parent.shape.y + (percent * parent.shape.height) - 1
	layout.shape.x = parent.shape.x
}
