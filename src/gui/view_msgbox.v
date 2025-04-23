module gui

pub struct MessageBoxCfg {
pub:
	title     string
	body      string
	on_ok     fn (mut Window) = fn (mut _ Window) {}
	on_cancel fn (mut Window) = fn (mut _ Window) {}
}

pub fn (mut window Window) message_box(cfg MessageBoxCfg) {
	w, h := window.window_size()
	view := column(
		width:   w / 2
		height:  h / 3
		fill:    true
		h_align: .center
		v_align: .middle
		padding: theme().padding_large
		content: [
			text(
				text:       cfg.title
				text_style: theme().b2
			),
			text(
				text:       cfg.body
				text_style: theme().n2
				wrap:       true
			),
			row(
				sizing:  fill_fit
				content: [
					button(
						content:  [text(text: 'OK')]
						on_click: fn [cfg] (b &ButtonCfg, mut e Event, mut w Window) {
							w.gen_modal_view = unsafe { nil }
							cfg.on_ok(mut w)
						}
					),
					button(
						content:  [text(text: 'Cancel')]
						on_click: fn [cfg] (b &ButtonCfg, mut e Event, mut w Window) {
							w.gen_modal_view = unsafe { nil }
							cfg.on_cancel(mut w)
						}
					),
				]
			),
		]
	)
	window.gen_modal_view = fn [view] (_ &Window) View {
		return view
	}
}
