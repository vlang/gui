module gui

@[heap]
pub struct MenuItemCfg {
pub:
	id             string @[required]
	text           string
	selected       bool
	selected_color Color = gui_theme.color_5
	sizing         Sizing
	radius         f32 = gui_theme.radius_small
	submenu        []MenuItemCfg
	separator      bool
	on_click       fn (&MenuItemCfg, mut Event, mut Window) = unsafe { nil }
}

pub fn menu_item(menubar_cfg MenubarCfg, menu_item_cfg MenuItemCfg) View {
	return match menu_item_cfg.separator {
		true {
			column(
				id:      menu_item_cfg.id
				height:  gui_theme.text_style.size / 2
				fill:    true
				sizing:  fill_fit
				padding: padding_none
				v_align: .middle
				content: [
					rectangle(
						height: 1
						color:  gui_theme.color_5
						sizing: fill_fit
					),
				]
			)
		}
		else {
			column(
				id:       menu_item_cfg.id
				cfg:      &menu_item_cfg
				color:    if menu_item_cfg.selected {
					menu_item_cfg.selected_color
				} else {
					color_transparent
				}
				fill:     menu_item_cfg.selected
				padding:  menubar_cfg.padding_submenu
				radius:   menu_item_cfg.radius
				sizing:   menu_item_cfg.sizing
				on_click: menubar_cfg.menu_item_click
				content:  [text(text: menu_item_cfg.text)]
			)
		}
	}
}

fn (menubar_cfg MenubarCfg) menu_item_click(cfg &MenuItemCfg, mut e Event, mut w Window) {
	w.view_state.menu_state[menubar_cfg.id_menubar] = cfg.id
	e.is_handled = true
}
