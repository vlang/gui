module gui

import datatypes

// MenubarCfg configures a horizontal menubar that supports nested submenus.
// A menubar holds MenuItemCfg items, each of which may contain further submenus.
// The id_focus value is required so the GUI system can track which menu is active.
//
// MenubarCfg is also used to configure standalone menu() instances.
//
// Theme:
// Menu-bars and their items follow the GUI's theme system. Menubar-level settings
// override theme defaults unless explicitly configured.
//
// Event Handling:
// - Each MenuItemCfg may have an action callback.
// - The MenubarCfg itself may have an action callback.
//   Both are called when a menu-item is activated (item action first, then menubar action).
// - Keyboard navigation is handled via on_keydown below.
//
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

	// Default menubar-level action. Called after the menu-item action.
	action fn (string, mut Event, mut Window) = fn (_ string, mut e Event, mut _ Window) {
		e.is_handled = true
	}

	items []MenuItemCfg

	// Width constraints for drop-down submenus.
	width_submenu_min f32 = gui_theme.menubar_style.width_submenu_min
	width_submenu_max f32 = gui_theme.menubar_style.width_submenu_max

	// Various corner radii for the bar, menu-items, and submenus.
	radius           f32 = gui_theme.menubar_style.radius
	radius_border    f32 = gui_theme.menubar_style.radius_border
	radius_submenu   f32 = gui_theme.menubar_style.radius_submenu
	radius_menu_item f32 = gui_theme.menubar_style.radius_menu_item

	// Spacing between items and between submenu elements.
	spacing         f32 = gui_theme.menubar_style.spacing
	spacing_submenu f32 = gui_theme.menubar_style.spacing_submenu

	// Required ID that the focus system uses to track this menubar.
	id_focus u32 @[required]

	// Float/anchor behavior when the menubar is positioned relative to the window region.
	float_anchor  FloatAttach
	float_tie_off FloatAttach

	// Visibility and interactivity flags.
	disabled  bool
	invisible bool
	float     bool
}

// menubar creates a menubar and all nested menus from a MenubarCfg definition.
//
// This handles:
// - Focus initialization
// - Duplicate ID validation
// - Construction of the row() containing menubar content
//
// The main bar includes a border container and an interior row where the menu items live.
pub fn (mut window Window) menubar(cfg MenubarCfg) View {
	if cfg.id_focus == 0 {
		panic('MenubarCfg.id_focus must be non-zero')
	}

	// Ensure all menu IDs (recursively) are unique.
	mut ids := datatypes.Set[string]{}
	if duplicate_id := check_menu_ids(cfg.items, mut ids) {
		panic('Duplicate menu-id found menubar-id "${cfg.id}": "${duplicate_id}"')
	}

	// If the menubar already has focus but no selected menu yet,
	// choose the first selectable menu item.
	if window.is_focus(cfg.id_focus) && window.view_state.menu_state[cfg.id_focus] == '' {
		for item in cfg.items {
			if is_selectable_menu_id(item.id) {
				window.view_state.menu_state[cfg.id_focus] = item.id
				break
			}
		}
	}

	// Construct the menubar UI tree.
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
				// menu_build handles constructing root items and their submenus.
				content: menu_build(cfg, 0, cfg.items, window)
			),
		]
	)
}

// MenuIdMap maps each menu ID to a MenuIdNode containing the four directional
// navigational neighbors. This is used for keyboard-based menu navigation.
type MenuIdMap = map[string]MenuIdNode

// MenuIdNode holds the IDs of the menu-items that should be navigated to when
// pressing left, right, up, or down while a given menu-item is focused.
struct MenuIdNode {
	left  string
	right string
	up    string
	down  string
}

// on_keydown handles menubar keyboard navigation.
//
// Supported keys:
// - escape: close menus & clear focus
// - space/enter: activate menu-item
// - arrows: navigate based on precomputed menu mapper
fn (cfg &MenubarCfg) on_keydown(_ &Layout, mut e Event, mut w Window) {
	// Currently selected menu ID for this menubar focus.
	menu_id := w.view_state.menu_state[cfg.id_focus]

	if e.key_code == .escape {
		// Close menus and drop focus.
		w.set_id_focus(0)
		w.view_state.menu_state[cfg.id_focus] = ''
		e.is_handled = true
		return
	}

	// Activate the current menu-item.
	if e.key_code in [.space, .enter] {
		menu_cfg := find_menu_by_id(cfg.items, menu_id)
		if menu_cfg != none {
			// Trigger menu-item action first.
			if menu_cfg.action != unsafe { nil } {
				menu_cfg.action(&menu_cfg, mut e, mut w)
			}
		}
		// Then trigger the menubar-level action.
		if cfg.action != unsafe { nil } {
			cfg.action(menu_id, mut e, mut w)
		}
		// Close after activation.
		w.set_id_focus(0)
		w.view_state.menu_state[cfg.id_focus] = ''
		e.is_handled = true
		return
	}

	// Determine new ID based on directional key.
	new_menu_id := match e.key_code {
		.left { menu_mapper(cfg.items)[menu_id].left }
		.right { menu_mapper(cfg.items)[menu_id].right }
		.up { menu_mapper(cfg.items)[menu_id].up }
		.down { menu_mapper(cfg.items)[menu_id].down }
		else { menu_id }
	}

	// Apply navigation if valid and selectable.
	if menu_id != new_menu_id && is_selectable_menu_id(new_menu_id) {
		w.view_state.menu_key_nav = true
		w.view_state.menu_state[cfg.id_focus] = new_menu_id
		e.is_handled = true
	}
}

// menu_mapper builds a mapping from each menu-item ID to its directional neighbors.
// This supports multi-level horizontal and vertical navigation.
//
// For each root-level item: left/right are siblings, up = itself, down = first submenu item.
fn menu_mapper(menu []MenuItemCfg) MenuIdMap {
	mut menu_map := MenuIdMap{}
	for idx, item in menu {
		if !is_selectable_menu_id(item.id) {
			continue
		}

		// Root-level navigation rules.
		node := MenuIdNode{
			left:  (menu[idx - 1] or { item }).id   // previous root item, or itself
			right: (menu[idx + 1] or { item }).id   // next root item, or itself
			up:    item.id              // up stays at root
			down:  (item.submenu[0] or { item }).id // go into first submenu item
		}
		menu_map[item.id] = node

		// Recursively process submenus.
		submenu_mapper(item.submenu, node.left, node, node, mut menu_map)
	}
	return menu_map
}

// submenu_mapper recursively defines navigation for submenu items.
//
// left_id    = ID to go to when left is pressed from submenu root
// node       = navigation node of immediate parent
// root_node  = navigation node of the root-level menu item (used for right/down transitions)
fn submenu_mapper(menu []MenuItemCfg, left_id string, node MenuIdNode, root_node MenuIdNode, mut menu_map MenuIdMap) {
	for idx, item in menu {
		if !is_selectable_menu_id(item.id) {
			continue
		}

		// Submenu navigation logic:
		// - Left jumps to parent (or parent's left)
		// - Right enters item's submenu if available, else root's right
		// - Up/Down move within submenu list
		subitem_node := MenuIdNode{
			left:  left_id
			right: menu_item_right(item, root_node.right)
			up:    menu_item_up(idx, menu, node.up)
			down:  menu_item_down(idx, menu, node.down)
		}
		menu_map[item.id] = subitem_node

		// Recurse into deeper levels.
		submenu_mapper(item.submenu, item.id, subitem_node, root_node, mut menu_map)
	}
}

// menu_item_right computes the right navigation target for a submenu item.
// Prefer the first selectable child menu-item, else fallback to root-right neighbor.
fn menu_item_right(item MenuItemCfg, id_right string) string {
	for subitem in item.submenu {
		if is_selectable_menu_id(subitem.id) {
			return subitem.id
		}
	}
	return id_right
}

// menu_item_up finds the nearest selectable menu-item above the current submenu index.
// If none, go to id_up (parent or root).
fn menu_item_up(idx int, items []MenuItemCfg, id_up string) string {
	for i := idx - 1; idx > 0; i-- {
		item := items[i] or { break }
		if is_selectable_menu_id(item.id) {
			return item.id
		}
	}
	return id_up
}

// menu_item_down finds the nearest selectable menu-item below the current submenu index.
// If none, go to id_down (parent or root).
fn menu_item_down(idx int, items []MenuItemCfg, id_down string) string {
	for i := idx + 1; true; i++ {
		item := items[i] or { break }
		if is_selectable_menu_id(item.id) {
			return item.id
		}
	}
	return id_down
}

// is_selectable_menu_id - A selectable menu ID is one that is not a separator or subtitle.
fn is_selectable_menu_id(id string) bool {
	return id !in [menu_separator_id, menu_subtitle_id]
}

// find_menu_by_id recursively locate a MenuItemCfg by its ID.
fn find_menu_by_id(items []MenuItemCfg, id string) ?MenuItemCfg {
	for item in items {
		if item.id == id {
			return item
		}
		find := find_menu_by_id(item.submenu, id)
		if find != none {
			return find
		}
	}
	return none
}
