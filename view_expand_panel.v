module gui

// ExpandPanelCfg configures an [expand_panel](#expand_panel)
@[heap]
pub struct ExpandPanelCfg {
pub:
	id             string
	open           bool
	color          Color   = gui_theme.expand_panel_style.color
	color_border   Color   = gui_theme.expand_panel_style.color_border
	fill           bool    = gui_theme.expand_panel_style.fill
	fill_border    bool    = gui_theme.expand_panel_style.fill_border
	padding        Padding = gui_theme.expand_panel_style.padding
	padding_border Padding = gui_theme.expand_panel_style.padding_border
	radius         f32     = gui_theme.expand_panel_style.radius
	radius_border  f32     = gui_theme.expand_panel_style.radius_border
	min_width      f32
	max_width      f32
	min_height     f32
	max_height     f32
	sizing         Sizing
	head           View
	content        View
	on_toggle      fn (mut w Window) = unsafe { nil }
}

// expand_pannl creates a expand view from the given [ExpandPanelCfg](#ExpandPanelCfg)
pub fn expand_panel(cfg ExpandPanelCfg) View {
	return column( // border
		id:         cfg.id
		cfg:        &cfg
		color:      cfg.color_border
		fill:       cfg.fill_border
		padding:    cfg.padding_border
		radius:     cfg.radius_border
		sizing:     cfg.sizing
		min_width:  cfg.min_width
		max_width:  cfg.max_width
		min_height: cfg.min_height
		max_height: cfg.max_height
		content:    [
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
							row(
								padding: padding(0, pad_medium, 0, 0)
								content: [
									text(
										text:       if cfg.open {
											icon_arrow_up
										} else {
											icon_arrow_down
										}
										text_style: gui_theme.icon3
									),
								]
							),
						]
						on_click: fn [cfg] (_ voidptr, mut e Event, mut w Window) {
							if cfg.on_toggle != unsafe { nil } {
								cfg.on_toggle(mut w)
								e.is_handled = true
							}
						}
						on_hover: fn (mut node Layout, mut e Event, mut w Window) {
							w.set_mouse_cursor_pointing_hand()
							node.shape.fill = true
							node.shape.color = gui_theme.color_hover
							e.is_handled = true
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
