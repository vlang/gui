module gui

@[heap]
pub struct MenuItemCfg {
pub:
	id             string @[required]
	text           string @[required]
	selected       bool
	selected_color Color = gui_theme.color_5
	radius         f32   = gui_theme.radius_small
	submenu        []MenuItemCfg
	on_click       fn (&MenuItemCfg, mut Event, mut Window) = unsafe { nil }
}

pub fn menu_item(menubar_cfg MenubarCfg, menu_item_cfg MenuItemCfg) ?View {
	return column(
		id:       menu_item_cfg.id
		cfg:      &menu_item_cfg
		color:    if menu_item_cfg.selected {
			menu_item_cfg.selected_color
		} else {
			color_transparent
		}
		fill:     menu_item_cfg.selected
		padding:  padding_two_five
		radius:   menu_item_cfg.radius
		on_click: menubar_cfg.menu_item_click
		content:  [text(text: menu_item_cfg.text)]
	)
}

fn (menubar_cfg MenubarCfg) menu_item_click(cfg &MenuItemCfg, mut e Event, mut w Window) {
	w.view_state.menu_state[menubar_cfg.id_menubar] = cfg.id
	e.is_handled = true
}
