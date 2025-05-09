module gui

@[heap]
pub struct MenuItemCfg {
pub:
	id             string @[required]
	text           string
	selected       bool
	color_selected Color     = gui_theme.menubar_style.color_selected
	radius         f32       = gui_theme.radius_small
	padding        Padding   = gui_theme.menubar_style.padding_menu_item
	spacing        f32       = gui_theme.menubar_style.spacing_submenu
	text_style     TextStyle = gui_theme.menubar_style.text_style
	sizing         Sizing
	submenu        []MenuItemCfg
	separator      bool
	on_click       fn (&MenuItemCfg, mut Event, mut Window) = unsafe { nil }
	custom_view    ?View
}

pub fn menu_item(menubar_cfg MenubarCfg, item_cfg MenuItemCfg) View {
	return match item_cfg.separator {
		true {
			column(
				id:      item_cfg.id
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
			mut content := []View{}
			if item_cfg.custom_view != none {
				content << item_cfg.custom_view
			} else {
				content << text(
					text:       item_cfg.text
					text_style: item_cfg.text_style
					wrap:       true
				)
			}
			column(
				id:       item_cfg.id
				cfg:      &item_cfg
				color:    if item_cfg.selected { item_cfg.color_selected } else { color_transparent }
				fill:     item_cfg.selected
				padding:  item_cfg.padding
				radius:   item_cfg.radius
				sizing:   item_cfg.sizing
				on_click: menubar_cfg.menu_item_click
				spacing:  item_cfg.spacing
				content:  content
			)
		}
	}
}

pub fn menu_item_text(id string, text string) MenuItemCfg {
	return MenuItemCfg{
		id:   id
		text: text
	}
}

pub fn menu_separator() MenuItemCfg {
	return MenuItemCfg{
		id:        'separator'
		separator: true
	}
}

fn (menubar_cfg MenubarCfg) menu_item_click(cfg &MenuItemCfg, mut e Event, mut w Window) {
	w.view_state.menu_state[menubar_cfg.id_menubar] = cfg.id
	e.is_handled = true
}
