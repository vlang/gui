module gui

//
pub enum AlertType {
	alert
	confirm
	prompt
}

// AlertCfg
pub struct AlertCfg {
mut:
	visible      bool
	old_id_focus u32
pub:
	alert_type     AlertType
	id             string
	width          f32
	height         f32
	min_width      f32 = 200
	min_height     f32
	max_width      f32 = 300
	max_height     f32
	title          string
	body           string
	id_focus       u32               = 7568971
	padding        Padding           = theme().padding_large
	padding_border Padding           = theme().padding_border
	on_ok_yes      fn (mut w Window) = fn (mut _ Window) {}
	on_cancel_no   fn (mut w Window) = fn (mut _ Window) {}
}

fn alert_view_generator(cfg AlertCfg) View {
	mut content := []View{}
	content << text(text: cfg.title, text_style: theme().b2)
	content << text(text: cfg.body, wrap: true)
	if cfg.alert_type == .alert {
		content << button(
			id_focus: cfg.id_focus
			content:  [text(text: 'OK')]
			on_click: fn (_ &ButtonCfg, mut e Event, mut w Window) {
				w.set_id_focus(w.alert_cfg.old_id_focus)
				on_ok_yes := w.alert_cfg.on_ok_yes
				w.alert_cfg = AlertCfg{}
				on_ok_yes(mut w)
				e.is_handled = true
			}
		)
	} else if cfg.alert_type == .confirm {
		content << row(
			content: [
				button(
					id_focus: cfg.id_focus + 1
					content:  [text(text: 'Yes')]
					on_click: fn (_ &ButtonCfg, mut e Event, mut w Window) {
						w.set_id_focus(w.alert_cfg.old_id_focus)
						on_ok_yes := w.alert_cfg.on_ok_yes
						w.alert_cfg = AlertCfg{}
						on_ok_yes(mut w)
						e.is_handled = true
					}
				),
				button(
					id_focus: cfg.id_focus
					content:  [text(text: 'No')]
					on_click: fn (_ &ButtonCfg, mut e Event, mut w Window) {
						w.set_id_focus(w.alert_cfg.old_id_focus)
						on_cancel_no := w.alert_cfg.on_cancel_no
						w.alert_cfg = AlertCfg{}
						on_cancel_no(mut w)
						e.is_handled = true
					}
				),
			]
		)
	}
	return column(
		float:         true
		float_anchor:  .middle_center
		float_tie_off: .middle_center
		color:         theme().color_border
		fill:          true
		padding:       cfg.padding_border
		width:         cfg.width
		height:        cfg.height
		min_width:     cfg.min_width
		max_width:     cfg.max_width
		min_height:    cfg.min_height
		max_height:    cfg.max_height
		content:       [
			column(
				sizing:  fill_fill
				padding: cfg.padding
				h_align: .center
				fill:    true
				color:   theme().color_2
				content: content
			),
		]
	)
}
