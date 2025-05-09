module gui

// MenuItemCfg configures a menu-item.  Menu items are containers and are not limited
// to text. There are three types of menu items.
//
// - separator, if the separator field is true, a horizontal line separating menu items is rendered.
// - custom view, if a custom_view is supplied, it is rendered.
// - text only, for convienence, a text field is availble for the typical text only menu items.
//
// If all three types are specified only one is rendereed. The priority is separator, custom view, text only.
// Regardless of the menu type, a menu item can have a submenu.
//
// The optional action callback can be used to process menu clicks. There is also a catch-all
// action callback in the [MenubarCfg](#MenubarCfg) that is called afterwards.
@[heap]
pub struct MenuItemCfg {
pub:
	id             string @[required]
	text           string    = 'empty'
	color_selected Color     = gui_theme.menubar_style.color_selected
	radius         f32       = gui_theme.menubar_style.radius_menu_item
	padding        Padding   = gui_theme.menubar_style.padding_menu_item
	spacing        f32       = gui_theme.menubar_style.spacing_submenu
	text_style     TextStyle = gui_theme.menubar_style.text_style
	disabled       bool
	selected       bool
	sizing         Sizing
	submenu        []MenuItemCfg
	separator      bool
	action         fn (&MenuItemCfg, mut Event, mut Window) = unsafe { nil }
	custom_view    ?View
}

fn menu_item(menubar_cfg MenubarCfg, item_cfg MenuItemCfg) View {
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
				disabled: item_cfg.disabled
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

// menu_item_text is a convienence function for creating a simple text menu item
pub fn menu_item_text(id string, text string) MenuItemCfg {
	return MenuItemCfg{
		id:   id
		text: text
	}
}

// menu_separator is a convienence function for createing a menu separator
pub fn menu_separator() MenuItemCfg {
	return MenuItemCfg{
		id:        'separator'
		separator: true
	}
}

fn (menubar_cfg MenubarCfg) menu_item_click(cfg &MenuItemCfg, mut e Event, mut w Window) {
	w.view_state.menu_state[menubar_cfg.id_menubar] = cfg.id
	if cfg.action != unsafe { nil } {
		cfg.action(cfg, mut e, mut w)
	}
	menubar_cfg.action(cfg.id, mut e, mut w)
	if cfg.submenu.len == 0 {
		w.view_state.menu_state[menubar_cfg.id_menubar] = ''
	}
}
