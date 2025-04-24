module gui

// AlertCfg
pub struct AlertCfg {
mut:
	visible      bool
	old_id_focus u32
pub:
	id         string
	width      f32
	height     f32
	min_width  f32 = 200
	min_height f32
	max_width  f32 = 300
	max_height f32
	title      string
	body       string
	id_focus   u32     = 7568971
	padding    Padding = theme().padding_large
}

fn alert_view_generator(cfg AlertCfg) View {
	return column(
		float:         true
		float_anchor:  .middle_center
		float_tie_off: .middle_center
		h_align:       .center
		color:         theme().color_5
		fill:          true
		padding:       cfg.padding
		width:         cfg.width
		height:        cfg.height
		min_width:     cfg.min_width
		max_width:     cfg.max_width
		min_height:    cfg.min_height
		max_height:    cfg.max_height
		amend_layout:  alert_amend_layout
		content:       [
			text(text: cfg.title, text_style: theme().b2),
			text(text: cfg.body, wrap: true),
			button(
				id_focus: cfg.id_focus
				content:  [text(text: 'OK')]
				on_click: fn (_ &ButtonCfg, mut e Event, mut w Window) {
					w.alert_cfg.visible = false
					w.set_id_focus(w.alert_cfg.old_id_focus)
					e.is_handled = true
				}
			),
		]
	)
}

fn alert_amend_layout(mut layout Layout, mut window Window) {
	if window.alert_cfg.visible {
		id_focus := window.alert_cfg.id_focus
		shape := layout.find_shape(fn [id_focus] (n Layout) bool {
			return n.shape.id_focus == id_focus
		})
		if shape != none {
			window.set_id_focus(shape.id_focus)
		}
	}
}
