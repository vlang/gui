module gui

import datatypes

// MenubarCfg configures a horizontal menubar, which can contain drop-down submenus,
// which in turn can have drop-down submenus. The `id_focus` is required so GUI can
// store which menu has been selected.
//
// For historical reasons: MenubarCfg is also used to configure [menu](#menu)
//
// Menu-bars and menu-items adhere to the same theme logic as other Gui views.
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
	text_style             TextStyle = gui_theme.menubar_style.text_style
	text_style_subtitle    TextStyle = gui_theme.menubar_style.text_style_subtitle
	color                  Color     = gui_theme.menubar_style.color
	color_border           Color     = gui_theme.menubar_style.color_border
	color_select           Color     = gui_theme.menubar_style.color_select
	sizing                 Sizing    = fill_fit
	padding                Padding   = gui_theme.menubar_style.padding
	padding_menu_item      Padding   = gui_theme.menubar_style.padding_menu_item
	padding_border         Padding   = gui_theme.menubar_style.padding_border
	padding_submenu        Padding   = gui_theme.menubar_style.padding_submenu
	padding_submenu_border Padding   = gui_theme.menubar_style.padding_border
	padding_subtitle       Padding   = gui_theme.menubar_style.padding_subtitle
	action                 fn (string, mut Event, mut Window) = fn (id string, mut e Event, mut w Window) {
		e.is_handled = true
	}
	items                  []MenuItemCfg
	width_submenu_min      f32 = gui_theme.menubar_style.width_submenu_min
	width_submenu_max      f32 = gui_theme.menubar_style.width_submenu_max
	radius                 f32 = gui_theme.menubar_style.radius
	radius_border          f32 = gui_theme.menubar_style.radius_border
	radius_submenu         f32 = gui_theme.menubar_style.radius_submenu
	radius_menu_item       f32 = gui_theme.menubar_style.radius_menu_item
	spacing                f32 = gui_theme.menubar_style.spacing
	spacing_submenu        f32 = gui_theme.menubar_style.spacing_submenu
	id_focus               u32 @[required]
	float_anchor           FloatAttach
	float_tie_off          FloatAttach
	disabled               bool
	invisible              bool
	float                  bool
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
		id_focus:      cfg.id_focus
		color:         cfg.color_border
		fill:          true
		float:         cfg.float
		float_anchor:  cfg.float_anchor
		float_tie_off: cfg.float_tie_off
		disabled:      cfg.disabled
		invisible:     cfg.invisible
		padding:       cfg.padding_border
		sizing:        cfg.sizing
		on_keydown:    cfg.on_keydown
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

// -----------------------------------------------------

struct MenuIdNode {
	left  string
	right string
	up    string
	down  string
}

// MenuIdMap as a list of surrounding menu ids for the given key (menu id)
// used for navigating the menu with the keyboard. Keyboard menu navigation
// is hard in that moving in horizontal direction can mean the next or
// previous menu maybe the parent menu or a submenu.
type MenuIdMap = map[string]MenuIdNode

fn (cfg &MenubarCfg) on_keydown(_ &Layout, mut e Event, mut w Window) {
	menu_id := w.view_state.menu_state[cfg.id_focus]
	new_menu_id := match e.key_code {
		.left { menu_mapper(cfg.items)[menu_id].left }
		.right { menu_mapper(cfg.items)[menu_id].right }
		.up { menu_mapper(cfg.items)[menu_id].up }
		.down { menu_mapper(cfg.items)[menu_id].down }
		else { menu_id }
	}
	if menu_id != new_menu_id && is_valid_menu_id(new_menu_id) {
		w.view_state.menu_key_nav = true
		w.view_state.menu_state[cfg.id_focus] = new_menu_id
		e.is_handled = true
	}
}

fn menu_mapper(menu []MenuItemCfg) MenuIdMap {
	mut menu_map := MenuIdMap{}
	for idx, item in menu {
		if !is_valid_menu_id(item.id) {
			continue
		}
		node := MenuIdNode{
			left:  (menu[idx - 1] or { item }).id
			right: (menu[idx + 1] or { item }).id
			up:    item.id
			down:  (item.submenu[0] or { item }).id
		}
		menu_map[item.id] = node
		submenu_mapper(item.submenu, menu, idx, menu, idx, mut menu_map)
	}
	return menu_map
}

fn submenu_mapper(menu []MenuItemCfg, parent []MenuItemCfg, parent_idx int, root []MenuItemCfg, root_idx int, mut menu_map MenuIdMap) {
	for idx, item in menu {
		if !is_valid_menu_id(item.id) {
			continue
		}
		node2 := MenuIdNode{
			left:  menu_item_left(parent_idx, parent, root_idx, root)
			right: menu_item_right(item, root, root_idx)
			up:    menu_item_up(idx, menu, parent_idx, parent)
			down:  menu_item_down(idx, menu, parent_idx, parent)
		}
		menu_map[item.id] = node2
		submenu_mapper(item.submenu, menu, idx, root, root_idx, mut menu_map)
	}
}

fn menu_item_left(idx int, menu []MenuItemCfg, root_idx int, root []MenuItemCfg) string {
	for i := idx; i > 0; i-- {
		id := menu[i].id
		if is_valid_menu_id(id) {
			if id == root[root_idx].id {
				break
			}
			return id
		}
	}
	return (root[root_idx - 1] or { root[root_idx] }).id
}

fn menu_item_right(item MenuItemCfg, parent []MenuItemCfg, parent_idx int) string {
	for subitem in item.submenu {
		if is_valid_menu_id(subitem.id) {
			return subitem.id
		}
	}
	return (parent[parent_idx + 1] or { return '' }).id
}

fn menu_item_up(idx int, items []MenuItemCfg, parent_idx int, parent []MenuItemCfg) string {
	for i := idx - 1; idx > 0; i-- {
		item := items[i] or { break }
		if is_valid_menu_id(item.id) {
			return item.id
		}
	}
	return parent[parent_idx].id
}

fn menu_item_down(idx int, items []MenuItemCfg, parent_idx int, parent []MenuItemCfg) string {
	for i := idx + 1; true; i++ {
		item := items[i] or { break }
		if is_valid_menu_id(item.id) {
			return item.id
		}
	}
	return parent[parent_idx].id
}

fn is_valid_menu_id(id string) bool {
	return !id.is_blank() && id !in [menu_separator_id, menu_subtitle_id]
}
