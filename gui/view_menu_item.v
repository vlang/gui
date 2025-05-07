module gui

pub struct MenuItemCfg {
pub:
	id             string @[required]
	text           string @[required]
	selected       bool
	selected_color Color = gui_theme.color_3
	radius         f32   = gui_theme.radius_small
	submenu        []View
	on_click       fn (&MenuItemCfg, mut Event, mut Window) = unsafe { nil }
}

pub fn menu_item(cfg MenuItemCfg) View {
	return column(
		id:       cfg.id
		color:    if cfg.selected { cfg.selected_color } else { color_transparent }
		fill:     cfg.selected
		padding:  Padding{2, 5, 2, 5}
		radius:   cfg.radius
		on_click: cfg.on_click
		content:  [text(text: cfg.text)]
	)
}
