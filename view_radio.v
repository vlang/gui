module gui

// RadioCfg configures a [radio](#radio) button.
@[heap; minify]
pub struct RadioCfg {
pub:
	id                 string
	label              string
	color              Color     = gui_theme.radio_style.color
	color_hover        Color     = gui_theme.radio_style.color_hover
	color_focus        Color     = gui_theme.radio_style.color_focus
	color_click        Color     = gui_theme.radio_style.color_click
	color_border       Color     = gui_theme.radio_style.color_border
	color_border_focus Color     = gui_theme.radio_style.color_border_focus
	color_select       Color     = gui_theme.radio_style.color_select
	color_unselect     Color     = gui_theme.radio_style.color_unselect
	padding            Padding   = gui_theme.radio_style.padding
	text_style         TextStyle = gui_theme.radio_style.text_style
	on_click           fn (&Layout, mut Event, mut Window) @[required]
	size               f32 = gui_theme.radio_style.size
	id_focus           u32
	disabled           bool
	select             bool
	invisible          bool
	size_border        f32 = gui_theme.radio_style.size_border
}

// radio creates a radio button UI component that allows users to select a
// single option from a group. The component consists of a circular button that
// can be selected or unselected, with an optional text label. The radio button
// supports hover and focus states, keyboard interaction (Space key), and can be
// disabled or made invisible. Visual customization includes colors for various
// states (normal, hover, focus, selected/unselected), padding, size, and text
// styling.
pub fn radio(cfg RadioCfg) View {
	mut content := []View{cap: 2}
	bdr_sz := if cfg.size_border == 0 {
		gui_theme.radio_style.size_border
	} else {
		cfg.size_border
	}

	// Capture values needed for callbacks by copy to avoid dangling reference to cfg
	color_focus := cfg.color_focus
	color_border_focus := cfg.color_border_focus
	color_hover := cfg.color_hover
	color_click := cfg.color_click

	content << circle(
		name:         'radio circle'
		width:        cfg.size
		height:       cfg.size
		color:        if cfg.select { cfg.color_select } else { cfg.color_unselect }
		color_border: cfg.color_border
		size_border:  bdr_sz
		radius:       cfg.size / 2 // Circle radius logic is automatic in render_circle but helpful for layout?
		disabled:     cfg.disabled
		invisible:    cfg.invisible
		sizing:       fixed_fixed
		h_align:      .center
		v_align:      .middle
	)

	if cfg.label.len > 0 {
		content << row(
			name: 'radio label'
			// pad the label to the right so hover color is past
			// end of text slightly.
			padding: padding(0, pad_x_small, 0, 0)
			content: [text(text: cfg.label, text_style: cfg.text_style)]
		)
	}

	return row(
		name:         'radio'
		id:           cfg.id
		id_focus:     cfg.id_focus
		padding:      cfg.padding
		v_align:      .middle
		on_click:     left_click_only(cfg.on_click)
		on_char:      spacebar_to_click(cfg.on_click)
		amend_layout: fn [color_focus, color_border_focus] (mut layout Layout, mut w Window) {
			if layout.shape.disabled || layout.shape.on_click == unsafe { nil } {
				return
			}
			if layout.children.len == 0 {
				return
			}
			if w.is_focus(layout.shape.id_focus) {
				layout.children[0].shape.color = color_focus
				layout.children[0].shape.color_border = color_border_focus
			}
		}
		on_hover:     fn [color_hover, color_click] (mut layout Layout, mut e Event, mut w Window) {
			w.set_mouse_cursor_pointing_hand()
			if layout.children.len == 0 {
				return
			}
			if !w.is_focus(layout.shape.id_focus) {
				layout.children[0].shape.color = color_hover
			}
			if e.mouse_button == .left {
				layout.children[0].shape.color = color_click
			}
		}
		content:      content
	)
}
