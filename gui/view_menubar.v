module gui

// MenubarCfg configures a horizontal menubar, which can contain drop-down submenu,
// which in turn can have drop-down menus. The `id_focus` is required so GUI can
// store which menu has been selected.
//
// Menubars and menu items adhere to the same theme logic as other Gui views.
// Menu-item clicks can be processed in two places. Each [MenuItemCfg](#MenuItemCfg)
// has an optional user action callback that is called when the menu-item is clicked.
// There is also optional user action callback on the Menubar. This is called after
// the optional menu-item is called. The menubar action callback allows processing
// some or all of the menu-item clicks in a single function if desired. Both can be
// employed used together.
@[heap]
pub struct MenubarCfg {
pub:
	id                     string
	id_focus               u32 @[required]
	disabled               bool
	invisible              bool
	color                  Color     = gui_theme.menubar_style.color
	color_border           Color     = gui_theme.menubar_style.color_border
	color_selected         Color     = gui_theme.menubar_style.color_selected
	width_submenu_min      f32       = gui_theme.menubar_style.width_submenu_min
	width_submenu_max      f32       = gui_theme.menubar_style.width_submenu_max
	padding                Padding   = gui_theme.menubar_style.padding
	padding_menu_item      Padding   = gui_theme.menubar_style.padding_menu_item
	padding_border         Padding   = gui_theme.menubar_style.padding_border
	padding_submenu        Padding   = gui_theme.menubar_style.padding_submenu
	padding_submenu_border Padding   = gui_theme.menubar_style.padding_border
	radius                 f32       = gui_theme.menubar_style.radius
	radius_border          f32       = gui_theme.menubar_style.radius_border
	radius_submenu         f32       = gui_theme.menubar_style.radius_submenu
	radius_menu_item       f32       = gui_theme.menubar_style.radius_menu_item
	sizing                 Sizing    = fill_fit
	spacing                f32       = gui_theme.menubar_style.spacing
	spacing_submenu        f32       = gui_theme.menubar_style.spacing_submenu
	text_style             TextStyle = gui_theme.menubar_style.text_style
	action                 fn (string, mut Event, mut Window) = fn (id string, mut e Event, mut w Window) {
		e.is_handled = true
	}
	items                  []MenuItemCfg
}

// menubar creates a menubar and its child menus from the given MenubarCfg
pub fn (window &Window) menubar(cfg MenubarCfg) View {
	if cfg.id_focus == 0 {
		panic('MenubarCfg.id_focus must be non-zero')
	}
	content := menu_build(cfg, 0, cfg.items, window)
	return row(
		id:           cfg.id
		color:        cfg.color_border
		fill:         true
		disabled:     cfg.disabled
		invisible:    cfg.invisible
		padding:      cfg.padding_border
		sizing:       cfg.sizing
		amend_layout: cfg.amend_layout_menubar
		content:      [
			row(
				color:   cfg.color
				fill:    true
				padding: cfg.padding
				spacing: cfg.spacing
				sizing:  cfg.sizing
				content: content
			),
		]
	)
}

fn menu_build(cfg MenubarCfg, level int, items []MenuItemCfg, window &Window) []View {
	mut content := []View{}
	id_selected := window.view_state.menu_state[cfg.id_focus]
	sizing := if level == 0 { fit_fit } else { fill_fit }
	for item in items {
		selected_in_tree := is_selected_in_tree(item.submenu, id_selected)
		item_cfg := MenuItemCfg{
			...item
			color_selected: cfg.color_selected
			padding:        cfg.padding_menu_item
			selected:       item.id == id_selected || selected_in_tree
			sizing:         sizing
			radius:         cfg.radius_menu_item
			spacing:        cfg.spacing_submenu
			text_style:     cfg.text_style
		}
		mut menu := menu_item(cfg, item_cfg)
		if item.submenu.len > 0 {
			if item_cfg.selected || selected_in_tree {
				submenu := column(
					min_width:      cfg.width_submenu_min
					max_width:      cfg.width_submenu_max
					color:          cfg.color_border
					padding:        cfg.padding_submenu_border
					fill:           true
					float:          true
					float_anchor:   if level == 0 { .bottom_left } else { .top_right }
					float_offset_y: if level == 0 { cfg.padding.bottom } else { 0 }
					content:        [
						column(
							color:   cfg.color
							fill:    true
							padding: cfg.padding_submenu
							spacing: cfg.spacing_submenu
							sizing:  fill_fill
							content: menu_build(cfg, level + 1, item.submenu, window)
						),
					]
				)
				menu.content << submenu
			}
		}
		content << menu
	}
	return content
}

fn is_selected_in_tree(submenu []MenuItemCfg, id_selected string) bool {
	for menu in submenu {
		if menu.id.len > 0 && menu.id == id_selected {
			return true
		}
		if is_selected_in_tree(menu.submenu, id_selected) {
			return true
		}
	}
	return false
}

fn (cfg &MenubarCfg) amend_layout_menubar(mut node Layout, mut w Window) {
	if !w.is_focus(cfg.id_focus) {
		w.view_state.menu_state[cfg.id_focus] = ''
	}
}
