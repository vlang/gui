module gui

import datatypes
import arrays

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

// menubar creates a menubar and all nested menus from a MenubarCfg definition
// It performs focus initialization, validates duplicate IDs recursively,
// assigns the first selectable menu when needed, and constructs the row()
// containing the border container and interior menu bar content.
// Returns the constructed top-level View for rendering.
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

// MenuIdMap maps each menu ID to a MenuIdNode containing directional neighbors.
type MenuIdMap = map[string]MenuIdNode

// MenuIdNode holds IDs representing left/right/up/down navigation destinations.
struct MenuIdNode {
	left  string
	right string
	up    string
	down  string
}

// on_keydown handles menubar keyboard navigation and activation
// escape clears focus and closes all menus
// space/enter activate the focused menu-item (item action first, then menubar action)
// left/right/up/down use the precomputed menu_mapper graph to relocate focus
fn (cfg &MenubarCfg) on_keydown(_ &Layout, mut e Event, mut w Window) {
	menu_id := w.view_state.menu_state[cfg.id_focus]

	if e.key_code == .escape {
		// Close menus and drop focus.
		w.set_id_focus(0)
		w.view_state.menu_state[cfg.id_focus] = ''
		e.is_handled = true
		return
	}

	if e.key_code in [.space, .enter] {
		menu_cfg := find_menu_by_id(cfg.items, menu_id)

		if menu_cfg != none {
			// menus with submenus don't allow action clicks
			if menu_cfg.submenu.len > 0 {
				e.is_handled = true
				return
			}
			// Trigger menu-item action first.
			if menu_cfg.action != unsafe { nil } {
				menu_cfg.action(&menu_cfg, mut e, mut w)
			}
		}
		// Then trigger the menubar-level action.
		if cfg.action != unsafe { nil } && !e.is_handled {
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

// menu_mapper builds a directional navigation map for all menu-items
// Root-level items receive left/right sibling navigation with wrapping,
// up=self, and down=first selectable submenu item.
// Submenus are added recursively via submenu_mapper to produce a full navigation graph.
fn menu_mapper(menu []MenuItemCfg) MenuIdMap {
	mut menu_map := MenuIdMap{}
	for idx, item in menu {
		if !is_selectable_menu_id(item.id) {
			continue
		}

		// Root-level navigation rules.
		node := MenuIdNode{
			left:  (previous_selectable(idx, menu) or { last_selectable(menu) or { item } }).id
			right: (next_selectable(idx, menu) or { first_selectable(menu) or { item } }).id
			up:    item.id
			down:  (first_selectable(item.submenu) or { item }).id
		}
		menu_map[item.id] = node

		// Recursively process submenus.
		submenu_mapper(item.submenu, node.left, node, node, mut menu_map)
	}
	return menu_map
}

// submenu_mapper assigns directional navigation for submenu entries
// left navigates to parent's left reference
// right enters submenu if present, otherwise uses the root-level right
// up/down move vertically within the submenu, with wraparound to last/first selectable items
// Recursively processes nested submenu levels to complete the graph.
fn submenu_mapper(menu []MenuItemCfg, left_id string, node MenuIdNode, root_node MenuIdNode, mut menu_map MenuIdMap) {
	for idx, item in menu {
		if !is_selectable_menu_id(item.id) {
			continue
		}

		// Submenu navigation logic:
		subitem_node := MenuIdNode{
			left:  left_id
			right: menu_item_right(item, root_node.right)
			up:    menu_item_up(idx, menu)
			down:  menu_item_down(idx, menu)
		}
		menu_map[item.id] = subitem_node

		// Recurse into deeper levels.
		submenu_mapper(item.submenu, item.id, subitem_node, root_node, mut menu_map)
	}
}

// menu_item_right computes right navigation for submenu items
// If a submenu exists, returns its first selectable item; otherwise falls back to root-right
fn menu_item_right(item MenuItemCfg, id_right string) string {
	first := first_selectable(item.submenu)
	return if first != none { first.id } else { id_right }
}

// menu_item_up finds the nearest selectable above idx within a submenu
// If none exist, wraps to the last selectable; if none selectable at all, returns current item
fn menu_item_up(idx int, items []MenuItemCfg) string {
	previous := previous_selectable(idx, items)
	if previous != none {
		return previous.id
	}
	last := last_selectable(items)
	if last != none {
		return last.id
	}
	return items[idx].id
}

// menu_item_down finds the nearest selectable below idx within a submenu
// If none exist, wraps to the first selectable; if none selectable at all, returns current item
fn menu_item_down(idx int, items []MenuItemCfg) string {
	next := next_selectable(idx, items)
	if next != none {
		return next.id
	}
	first := first_selectable(items)
	if first != none {
		return first.id
	}
	return items[idx].id
}

// is_selectable_menu_id determines whether a menu ID corresponds to a real menu-item
// Separator and subtitle IDs are not selectable, so navigation skips them
fn is_selectable_menu_id(id string) bool {
	return id !in [menu_separator_id, menu_subtitle_id]
}

// find_menu_by_id recursively searches for a MenuItemCfg matching the given ID
// Returns the found item or none if no match is found anywhere in nested submenus
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

// next_selectable finds the next selectable menu-item after the given index
// Skips separators and subtitles; returns none if no selectable item follows
fn next_selectable(idx int, menu []MenuItemCfg) ?MenuItemCfg {
	for i := idx + 1; true; i++ {
		item := menu[i] or { break }
		if is_selectable_menu_id(item.id) {
			return item
		}
	}
	return none
}

// previous_selectable finds the previous selectable menu-item before the given index
// Skips separators and subtitles; returns none if no selectable item exists above
fn previous_selectable(idx int, menu []MenuItemCfg) ?MenuItemCfg {
	for i := idx - 1; true; i-- {
		item := menu[i] or { break }
		if is_selectable_menu_id(item.id) {
			return item
		}
	}
	return none
}

// first_selectable returns the first selectable entry from a menu slice
// Skips non-selectable items; returns none if the menu contains no selectable entries
fn first_selectable(menu []MenuItemCfg) ?MenuItemCfg {
	for item in menu {
		if is_selectable_menu_id(item.id) {
			return item
		}
	}
	return none
}

// last_selectable returns the last selectable entry from a menu slice
// Uses reverse iteration; returns none if no selectable entry exists
fn last_selectable(menu []MenuItemCfg) ?MenuItemCfg {
	for item in arrays.reverse_iterator(menu) {
		if is_selectable_menu_id(item.id) {
			return *item
		}
	}
	return none
}
