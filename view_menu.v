module gui

import datatypes
import log

// menu builds the top-level columnar menu view. Historically this was part of the
// menubar implementation, so it still uses `MenubarCfg`. It creates the outer border
// and interior containers, and delegates actual menu item creation to `menu_build`.
// Requires `cfg.id_focus` to be non-zero so the view state can track selected items.
pub fn (window &Window) menu(cfg MenubarCfg) View {
	mut c := cfg
	if c.id_focus == 0 {
		log.warn('MenubarCfg.id_focus must be non-zero; generating fallback ID')
		c.id_focus = u32(c.id.hash()) ^ 0xDEADBEEF
		if c.id_focus == 0 {
			c.id_focus = 7568971
		}
	}
	check_for_duplicate_menu_ids(c.items)
	return column(
		name:          'menubar'
		id:            c.id
		color:         c.color
		float:         c.float
		float_anchor:  c.float_anchor
		float_tie_off: c.float_tie_off
		invisible:     c.invisible
		size_border:   c.size_border
		color_border:  c.color_border

		radius:       c.radius
		sizing:       c.sizing
		amend_layout: make_menu_amend_layout(c.id_focus)
		padding:      c.padding_submenu
		spacing:      c.spacing_submenu
		content:      menu_build(c, 1, c.items, window)
	)
}

// Wrapper function to capture minimal values needed for amend_layout.
fn make_menu_amend_layout(id_focus u32) fn (mut Layout, mut Window) {
	return fn [id_focus] (mut layout Layout, mut w Window) {
		if !w.is_focus(id_focus) {
			w.view_state.menu_state.set(id_focus, '')
		}
	}
}

// menu_build Recursively constructs menu items and nested submenus. It determines
// item padding, text styles, and selection state; highlights active menu paths; and
// when selected, attaches floating submenu panels. `level` is used to determine sizing
// and which side submenus are anchored to.
fn menu_build(cfg MenubarCfg, level int, items []MenuItemCfg, window &Window) []View {
	mut content := []View{cap: items.len}

	id_selected := window.view_state.menu_state.get(cfg.id_focus) or { '' }
	sizing := if level == 0 { fit_fit } else { fill_fit }

	for item in items {
		selected_in_tree := is_menu_id_in_tree(item.submenu, id_selected)

		// Choose padding depending on whether item has a custom view,
		// is a subtitle, or is a normal item.
		padding := match item.custom_view != none {
			true {
				item.padding
			}
			else {
				match item.id == menu_subtitle_id {
					true { cfg.padding_subtitle }
					else { cfg.padding_menu_item }
				}
			}
		}

		text_style := if item.id == menu_subtitle_id {
			cfg.text_style_subtitle
		} else {
			cfg.text_style
		}

		item_cfg := MenuItemCfg{
			...item
			color_select: cfg.color_select
			padding:      padding
			selected:     item.id == id_selected || selected_in_tree
			sizing:       sizing
			radius:       cfg.radius_menu_item
			spacing:      cfg.spacing_submenu
			text_style:   text_style
		}

		mut mi := menu_item(cfg, item_cfg)

		// Attach floating submenu if the item is selected or part of the open menu path.
		if item.submenu.len > 0 {
			if item_cfg.selected || selected_in_tree {
				// Extract id_focus for closure capture
				id_focus := cfg.id_focus
				submenu := column(
					name:         'menubar submenu'
					id:           item_cfg.id
					min_width:    cfg.width_submenu_min
					max_width:    cfg.width_submenu_max
					color:        cfg.color
					size_border:  cfg.size_border
					color_border: cfg.color_border

					float:          true
					float_anchor:   if level == 0 {
						if gui_locale.text_dir == .rtl {
							FloatAttach.bottom_right
						} else {
							FloatAttach.bottom_left
						}
					} else {
						if gui_locale.text_dir == .rtl {
							FloatAttach.top_left
						} else {
							FloatAttach.top_right
						}
					}
					float_offset_y: if level == 0 { cfg.padding.bottom } else { 0 }
					on_hover:       make_submenu_on_hover(cfg)
					on_click:       fn [id_focus] (_ &Layout, mut e Event, mut w Window) {
						e.is_handled = true
						w.set_id_focus(id_focus)
					}
					padding:        cfg.padding_submenu
					spacing:        cfg.spacing_submenu
					sizing:         fill_fill
					content:        menu_build(cfg, level + 1, item.submenu, window)
				)
				mi.content << submenu
			}
		}

		content << mi
	}
	return content
}

// make_submenu_on_hover creates an optimized hover handler for submenus.
// Uses 'make_*' prefix for functions that create closures with minimal captures,
// following the optimization pattern from view_button.v. This differs from 'on_*'
// methods which are event handlers on structs.
fn make_submenu_on_hover(cfg MenubarCfg) fn (mut Layout, mut Event, mut Window) {
	id_focus := cfg.id_focus
	items := cfg.items
	return fn [id_focus, items] (mut layout Layout, mut _ Event, mut w Window) {
		id_selected := w.view_state.menu_state.get(id_focus) or { '' }
		has_selected := descendant_has_menu_id(layout, id_selected)

		if has_selected {
			ctx := w.context()
			// If mouse leaves the submenu panel…
			if !layout.shape.point_in_shape(f32(ctx.mouse_pos_x), f32(ctx.mouse_pos_y)) {
				// …and the selected item is a leaf (has no submenu),
				// then highlight the parent menu item (id = layout.shape.id).
				if mi_cfg := find_menu_item_cfg(items, id_selected) {
					if mi_cfg.submenu.len == 0 {
						w.view_state.menu_state.set(id_focus, layout.shape.id)
					}
				}
			}
		}
	}
}

// descendant_has_menu_id searches the layout tree to see whether a given menu-id
// appears anywhere within this layout or its descendants. Used to detect whether
// the currently selected menu item resides in a specific submenu panel.
fn descendant_has_menu_id(layout &Layout, id string) bool {
	if layout.shape.id == id {
		return true
	}
	for child in layout.children {
		if descendant_has_menu_id(child, id) {
			return true
		}
	}
	return false
}

// find_menu_item_cfg recursively searches the MenuItemCfg tree for an item by id.
// Returns the matched item if found, or none otherwise.
fn find_menu_item_cfg(items []MenuItemCfg, id string) ?MenuItemCfg {
	for item in items {
		if item.id == id {
			return item
		}
		if itm := find_menu_item_cfg(item.submenu, id) {
			return itm
		}
	}
	return none
}

// check_for_duplicate_menu_ids ensures unique menu item ids across the entire
// menu hierarchy (except for predefined special ids).
fn check_for_duplicate_menu_ids(items []MenuItemCfg) {
	mut ids := datatypes.Set[string]{}
	if duplicate_id := check_menu_ids(items, mut ids) {
		log.warn('Duplicate menu ID detected: "${duplicate_id}". Menu behavior may be inconsistent.')
	}
}

// check_menu_ids is a recursive helper that inserts ids into a Set, returning the
// first duplicate encountered, or none if all ids are unique. Ignores special ids.
fn check_menu_ids(items []MenuItemCfg, mut ids datatypes.Set[string]) ?string {
	for item in items {
		if ids.exists(item.id) {
			return item.id
		}
		if item.id !in [menu_separator_id, menu_subtitle_id] {
			ids.add(item.id)
		}
		if id := check_menu_ids(item.submenu, mut ids) {
			return id
		}
	}
	return none
}

// is_menu_id_in_tree returns true if the given id is anywhere in the submenu tree.
// Used to highlight intermediate menu-items that lead to the currently open subtree.
fn is_menu_id_in_tree(submenu []MenuItemCfg, id string) bool {
	for menu in submenu {
		if menu.id == id {
			return true
		}
		if is_menu_id_in_tree(menu.submenu, id) {
			return true
		}
	}
	return false
}
