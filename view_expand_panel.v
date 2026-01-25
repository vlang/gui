module gui

// ExpandPanelCfg configures an [expand_panel](#expand_panel).
// It consists of a header (always visible) and content (visible when expanded).
@[minify]
pub struct ExpandPanelCfg {
pub:
	on_toggle    fn (mut w Window) = unsafe { nil }
	id           string
	head         View
	content      View
	sizing       Sizing
	color        Color   = gui_theme.expand_panel_style.color
	color_border Color   = gui_theme.expand_panel_style.color_border
	padding      Padding = gui_theme.expand_panel_style.padding
	border_width f32     = gui_theme.expand_panel_style.border_width

	radius        f32 = gui_theme.expand_panel_style.radius
	radius_border f32 = gui_theme.expand_panel_style.radius_border
	min_width     f32
	max_width     f32
	min_height    f32
	max_height    f32
	open          bool
	fill          bool = gui_theme.expand_panel_style.fill
	fill_border   bool = gui_theme.expand_panel_style.fill_border
}

// expand_panel creates an expandable panel view.
pub fn expand_panel(cfg ExpandPanelCfg) View {
	on_toggle := cfg.on_toggle
	return column(
		name:         'expand_panel border'
		id:           cfg.id
		color:        cfg.color_border
		fill:         cfg.fill_border
		border_width: cfg.border_width

		radius:     cfg.radius_border
		sizing:     cfg.sizing
		min_width:  cfg.min_width
		max_width:  cfg.max_width
		min_height: cfg.min_height
		max_height: cfg.max_height
		content:    [
			column(
				name:    'expand_panel interior'
				color:   cfg.color
				fill:    cfg.fill
				padding: cfg.padding
				radius:  cfg.radius
				sizing:  fill_fit
				spacing: 0
				content: [
					row(
						name:     'expand_panel head'
						padding:  padding_none
						sizing:   fill_fit
						v_align:  .middle
						content:  [
							cfg.head,
							row(
								name:    'expand_panel head row'
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
						on_click: fn [on_toggle] (_ voidptr, mut e Event, mut w Window) {
							if on_toggle != unsafe { nil } {
								on_toggle(mut w)
								e.is_handled = true
							}
						}
						on_hover: fn (mut layout Layout, mut e Event, mut w Window) {
							w.set_mouse_cursor_pointing_hand()
							layout.shape.fill = true
							layout.shape.color = gui_theme.color_hover
							e.is_handled = true
						}
					),
					column(
						name:      'expand_panel content'
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
