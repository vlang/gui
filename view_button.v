module gui

// ButtonCfg configures a clickable [button](#button). It won't respond to
// mouse interactions if an on_click handler is not provided. In that mode,
// it functions as bubble text.
@[heap; minify]
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
	on_click           fn (&Layout, mut Event, mut Window) = unsafe { nil }
	on_hover           fn (&Layout, mut Event, mut Window) = unsafe { nil }
	width              f32
	height             f32
	min_width          f32
	min_height         f32
	max_width          f32
	max_height         f32
	radius             f32 = gui_theme.button_style.radius
	radius_border      f32 = gui_theme.button_style.radius_border
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
// 	on_click:       fn (_ &gui.Layout, _ &gui.Event, mut w gui.Window) bool {
// 		mut app := w.state[App]()
// 		app.clicks += 1
// 		return true
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
	return row(
		name:         'button'
		id:           cfg.id
		id_focus:     cfg.id_focus
		color:        cfg.color
		color_border: cfg.color_border
		size_border:  cfg.size_border
		blur_radius:  cfg.blur_radius
		shadow:       cfg.shadow
		gradient:     cfg.gradient
		padding:      cfg.padding
		radius:       cfg.radius
		width:        cfg.width
		height:       cfg.height
		min_width:    cfg.min_width
		max_width:    cfg.max_width
		min_height:   cfg.min_height
		max_height:   cfg.max_height
		sizing:       cfg.sizing
		disabled:     cfg.disabled
		invisible:    cfg.invisible
		h_align:      cfg.h_align
		v_align:      cfg.v_align
		tooltip:      cfg.tooltip
		on_click:     cfg.on_click
		on_char:      spacebar_to_click(cfg.on_click)
		amend_layout: fn [color_focus, color_border_focus] (mut layout Layout, mut w Window) {
			if layout.shape.disabled || layout.shape.on_click == unsafe { nil } {
				return
			}
			if w.is_focus(layout.shape.id_focus) {
				layout.shape.color = color_focus
				layout.shape.color_border = color_border_focus
			}
		}
		on_hover:     fn [color_hover, color_click, user_on_hover] (mut layout Layout, mut e Event, mut w Window) {
			if layout.shape.on_click == unsafe { nil } {
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
		content:      cfg.content
	)
}
