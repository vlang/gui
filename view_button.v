module gui

import time

// ButtonCfg configures a clickable [button](#button). It won't respond to
// mouse interactions if an on_click handler is not provided. In that mode,
// it functions as bubble text.
@[minify]
pub struct ButtonCfg {
pub:
	id                 string
	tooltip            &TooltipCfg = unsafe { nil }
	color              Color       = gui_theme.button_style.color
	color_hover        Color       = gui_theme.button_style.color_hover
	color_focus        Color       = gui_theme.button_style.color_focus
	color_click        Color       = gui_theme.button_style.color_click
	color_border       Color       = gui_theme.button_style.color_border
	color_border_focus Color       = gui_theme.button_style.color_border_focus
	padding            Padding     = gui_theme.button_style.padding
	size_border        f32         = gui_theme.button_style.size_border
	blur_radius        f32         = gui_theme.button_style.blur_radius
	shadow             &BoxShadow  = gui_theme.button_style.shadow
	gradient           &Gradient   = gui_theme.button_style.gradient
	sizing             Sizing
	content            []View
	alt_content        []View
	alt_duration       time.Duration
	show_alt           bool
	on_click           fn (&Layout, mut Event, mut Window) = unsafe { nil }
	on_hover           fn (&Layout, mut Event, mut Window) = unsafe { nil }
	float              bool
	float_anchor       FloatAttach
	float_tie_off      FloatAttach
	float_offset_x     f32
	float_offset_y     f32
	width              f32
	height             f32
	min_width          f32
	min_height         f32
	max_width          f32
	max_height         f32
	radius             f32 = gui_theme.button_style.radius
	id_focus           u32
	h_align            HorizontalAlign = .center
	v_align            VerticalAlign   = .middle
	disabled           bool
	invisible          bool
}

// button creates a clickable button. Buttons can contain content other than text.
// See [ButtonCfg](#ButtonCfg)
// Example:
// ```v
// gui.button(
// 	min_width:      90
// 	max_width:      90
// 	size_border:   1
// 	content:        [gui.text(text: '${app.clicks} Clicks')]
// 	on_click:       fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
// 		mut app := w.state[App]()
// 		app.clicks += 1
// 	}
// )
// ```
pub fn button(cfg ButtonCfg) View {
	// Capture values needed for hover handling by copy to avoid dangling reference to cfg
	color_hover := cfg.color_hover
	color_click := cfg.color_click
	color_focus := cfg.color_focus
	color_border_focus := cfg.color_border_focus
	user_on_hover := cfg.on_hover

	resolved_content := if cfg.show_alt && cfg.alt_content.len > 0 {
		cfg.alt_content
	} else {
		cfg.content
	}

	mut resolved_on_click := cfg.on_click
	if cfg.alt_content.len > 0 && cfg.alt_duration > 0 {
		user_on_click := cfg.on_click
		anim_id := 'btn_alt_${cfg.id}'
		alt_dur := cfg.alt_duration
		resolved_on_click = fn [user_on_click, anim_id, alt_dur] (layout &Layout, mut e Event, mut w Window) {
			if user_on_click != unsafe { nil } {
				user_on_click(layout, mut e, mut w)
			}
			w.animation_add(mut Animate{
				id:       anim_id
				delay:    alt_dur
				callback: fn (mut _ Animate, mut _ Window) {}
			})
			e.is_handled = true
		}
	}

	return row(
		name:           'button'
		id:             cfg.id
		id_focus:       cfg.id_focus
		color:          cfg.color
		color_border:   cfg.color_border
		size_border:    cfg.size_border
		blur_radius:    cfg.blur_radius
		shadow:         cfg.shadow
		gradient:       cfg.gradient
		padding:        cfg.padding
		radius:         cfg.radius
		width:          cfg.width
		height:         cfg.height
		min_width:      cfg.min_width
		max_width:      cfg.max_width
		min_height:     cfg.min_height
		max_height:     cfg.max_height
		sizing:         cfg.sizing
		disabled:       cfg.disabled
		invisible:      cfg.invisible
		h_align:        cfg.h_align
		v_align:        cfg.v_align
		tooltip:        cfg.tooltip
		float:          cfg.float
		float_anchor:   cfg.float_anchor
		float_tie_off:  cfg.float_tie_off
		float_offset_x: cfg.float_offset_x
		float_offset_y: cfg.float_offset_y
		on_click:       resolved_on_click
		on_char:        spacebar_to_click(resolved_on_click)
		amend_layout:   fn [color_focus, color_border_focus] (mut layout Layout, mut w Window) {
			if layout.shape.disabled || !layout.shape.has_events()
				|| layout.shape.events.on_click == unsafe { nil } {
				return
			}
			if w.is_focus(layout.shape.id_focus) {
				layout.shape.color = color_focus
				layout.shape.color_border = color_border_focus
			}
		}
		on_hover:       fn [color_hover, color_click, user_on_hover] (mut layout Layout, mut e Event, mut w Window) {
			if !layout.shape.has_events() || layout.shape.events.on_click == unsafe { nil } {
				return
			}
			w.set_mouse_cursor_pointing_hand()
			if !w.is_focus(layout.shape.id_focus) {
				layout.shape.color = color_hover
			}
			if e.mouse_button == .left {
				layout.shape.color = color_click
			}
			if user_on_hover != unsafe { nil } {
				user_on_hover(layout, mut e, mut w)
			}
		}
		content:        resolved_content
	)
}
