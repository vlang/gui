module gui

import datatypes

// MenubarCfg configures a horizontal menubar, which can contain drop-down submenus,
// which in turn can have drop-down submenus. The `id_focus` is required so GUI can
// store which menu has been selected.
//
// For historical reasons: MenubarCfg is also used to configure [menu](#menu)
//
// Menubars and menu-items adhere to the same theme logic as other Gui views.
// Menu-item clicks can be processed in two places. Each [MenuItemCfg](#MenuItemCfg)
// has an optional user action callback that is called when the menu-item is clicked.
// There is also an optional user action callback on the Menubar. This is called after
// the optional menu-item is called. The menubar action callback allows processing
// some or all of the menu-item clicks in a single function if desired. Both can be
// used together.
@[heap]
pub struct MenubarCfg {
pub:
	id                     string
	id_focus               u32 @[required]
	disabled               bool
	invisible              bool
	float                  bool
	float_anchor           FloatAttach
	float_tie_off          FloatAttach
	color                  Color     = gui_theme.menubar_style.color
	color_border           Color     = gui_theme.menubar_style.color_border
	color_select           Color     = gui_theme.menubar_style.color_select
	width_submenu_min      f32       = gui_theme.menubar_style.width_submenu_min
	width_submenu_max      f32       = gui_theme.menubar_style.width_submenu_max
	padding                Padding   = gui_theme.menubar_style.padding
	padding_menu_item      Padding   = gui_theme.menubar_style.padding_menu_item
	padding_border         Padding   = gui_theme.menubar_style.padding_border
	padding_submenu        Padding   = gui_theme.menubar_style.padding_submenu
	padding_submenu_border Padding   = gui_theme.menubar_style.padding_border
	padding_subtitle       Padding   = gui_theme.menubar_style.padding_subtitle
	radius                 f32       = gui_theme.menubar_style.radius
	radius_border          f32       = gui_theme.menubar_style.radius_border
	radius_submenu         f32       = gui_theme.menubar_style.radius_submenu
	radius_menu_item       f32       = gui_theme.menubar_style.radius_menu_item
	sizing                 Sizing    = fill_fit
	spacing                f32       = gui_theme.menubar_style.spacing
	spacing_submenu        f32       = gui_theme.menubar_style.spacing_submenu
	text_style             TextStyle = gui_theme.menubar_style.text_style
	text_style_subtitle    TextStyle = gui_theme.menubar_style.text_style_subtitle
	action                 fn (string, mut Event, mut Window) = fn (id string, mut e Event, mut w Window) {
		e.is_handled = true
	}
	items                  []MenuItemCfg
}

// menubar creates a menubar and its child menus from the given [MenubarCfg](#MenubarCfg)
pub fn (window &Window) menubar(cfg MenubarCfg) View {
	if cfg.id_focus == 0 {
		panic('MenubarCfg.id_focus must be non-zero')
	}
	mut ids := datatypes.Set[string]{}
	if duplicate_id := check_menu_ids(cfg.items, mut ids) {
		panic('Duplicate menu-id found menubar-id "${cfg.id}": "${duplicate_id}"')
	}
	return row(
		name:          'menubar border'
		id:            cfg.id
		color:         cfg.color_border
		fill:          true
		float:         cfg.float
		float_anchor:  cfg.float_anchor
		float_tie_off: cfg.float_tie_off
		disabled:      cfg.disabled
		invisible:     cfg.invisible
		padding:       cfg.padding_border
		sizing:        cfg.sizing
		amend_layout:  cfg.amend_layout_menubar
		content:       [
			row(
				name:    'menubar interior'
				color:   cfg.color
				fill:    true
				padding: cfg.padding
				spacing: cfg.spacing
				sizing:  cfg.sizing
				radius:  cfg.radius
				content: menu_build(cfg, 0, cfg.items, window)
			),
		]
	)
}

fn is_selected_in_tree(submenu []MenuItemCfg, id_selected string) bool {
	// This is how menubar knows to highlight the intermediate menu-items
	// leading up to an open submenu.
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
