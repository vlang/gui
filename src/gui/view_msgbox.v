module gui

pub struct MsgBoxCfg {
mut:
	visible      bool
	old_id_focus u32
pub:
	title      string
	body       string
	width      f32
	height     f32
	min_width  f32 = 200
	max_width  f32 = 300
	min_height f32
	max_height f32
	id_focus   u32     = 7568971
	padding    Padding = theme().padding_large
}

fn msgbox_view_generator(cfg MsgBoxCfg) View {
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
		amend_layout:  msgbox_amend_layout
		content:       [
			text(text: cfg.title, text_style: theme().b2),
			text(text: cfg.body, wrap: true),
			button(
				id_focus: cfg.id_focus
				content:  [text(text: 'OK')]
				on_click: fn (_ &ButtonCfg, mut e Event, mut w Window) {
					w.msg_box_cfg.visible = false
					w.set_id_focus(w.msg_box_cfg.old_id_focus)
					e.is_handled = true
				}
			),
		]
	)
}

fn msgbox_amend_layout(mut layout Layout, mut window Window) {
	if window.msg_box_cfg.visible {
		id_focus := window.msg_box_cfg.id_focus
		shape := layout.find_shape(fn [id_focus] (n Layout) bool {
			return n.shape.id_focus == id_focus
		})
		if shape != none {
			window.set_id_focus(shape.id_focus)
		}
	}
}
