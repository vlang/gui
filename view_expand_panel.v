module gui

@[heap]
pub struct ExpandPanelCfg {
pub:
	id             string
	open           bool
	color          Color   = gui_theme.color_interior
	color_border   Color   = gui_theme.color_border
	fill           bool    = true
	fill_border    bool    = true
	padding        Padding = gui_theme.padding_medium
	padding_border Padding = padding_one
	radius         f32     = gui_theme.radius_medium
	radius_border  f32     = gui_theme.radius_medium
	sizing         Sizing
	head           View
	content        View
	on_toggle      fn (mut w Window) = unsafe { nil }
}

pub fn expand_panel(cfg ExpandPanelCfg) View {
	return column( // border
		id:      cfg.id
		cfg:     &cfg
		color:   cfg.color_border
		fill:    cfg.fill_border
		padding: cfg.padding_border
		radius:  cfg.radius_border
		sizing:  cfg.sizing
		content: [
			column( // interior
				color:   cfg.color
				fill:    cfg.fill
				padding: cfg.padding
				radius:  cfg.radius
				sizing:  fill_fit
				spacing: 0
				content: [
					row( // top panel
						padding:  padding_none
						sizing:   fill_fit
						v_align:  .middle
						content:  [
							cfg.head,
							text(
								text:       if cfg.open { icon_arrow_up } else { icon_arrow_down }
								text_style: gui_theme.icon3
							),
						]
						on_click: fn [cfg] (_ voidptr, mut e Event, mut w Window) {
							if cfg.on_toggle != unsafe { nil } {
								cfg.on_toggle(mut w)
							}
						}
						on_hover: fn (mut _ Layout, mut _ Event, mut w Window) {
							w.set_mouse_cursor_pointing_hand()
						}
					),
					column( // expand panel
						invisible: !cfg.open
						padding:   padding_none
						sizing:    fill_fit
						spacing:   0
						content:   [
							cfg.content,
						]
					),
				]
			),
		]
	)
}
