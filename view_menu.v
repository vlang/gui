module gui

import datatypes

// menu creates a columnar menu. Originally, this was part of menubar and only
// later was separated out. For this reason, it still uses [MenubarCfg](#MenuBarCfg).
// See `examples/context_menu_demo.v` for an example of how to use `menu`.
// Apologies to future me...
pub fn (mut window Window) menu(cfg MenubarCfg) View {
	if cfg.id_focus == 0 {
		panic('MenubarCfg.id_focus must be non-zero')
	}
	mut ids := datatypes.Set[string]{}
	if duplicate_id := check_menu_ids(cfg.items, mut ids) {
		panic('Duplicate menu-id found menubar-id "${cfg.id}": "${duplicate_id}"')
	}
	return column(
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
		radius:        cfg.radius_border
		sizing:        cfg.sizing
		amend_layout:  cfg.amend_layout_menubar
		content:       [
			column(
				name:    'menubar interior'
				color:   cfg.color
				fill:    true
				padding: cfg.padding_submenu
				spacing: cfg.spacing_submenu
				sizing:  cfg.sizing
				radius:  cfg.radius
				content: menu_build(cfg, 1, cfg.items, window)
			),
		]
	)
}

fn menu_build(cfg MenubarCfg, level int, items []MenuItemCfg, window &Window) []View {
	mut content := []View{}
	unsafe { content.flags.set(.noslices) }
	defer { unsafe { content.flags.clear(.noslices) } }
	id_selected := window.view_state.menu_state[cfg.id_focus]
	sizing := if level == 0 { fit_fit } else { fill_fit }
	for item in items {
		selected_in_tree := is_selected_in_tree(item.submenu, id_selected)
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
		if item.submenu.len > 0 {
			if item_cfg.selected || selected_in_tree {
				submenu := column(
					name:           'menubar submenu border'
					id:             item_cfg.id // parent id
					min_width:      cfg.width_submenu_min
					max_width:      cfg.width_submenu_max
					color:          cfg.color_border
					padding:        cfg.padding_submenu_border
					fill:           true
					float:          true
					float_anchor:   if level == 0 { .bottom_left } else { .top_right }
					float_offset_y: if level == 0 { cfg.padding.bottom } else { 0 }
					on_hover:       cfg.on_hover_submenu
					content:        [
						column(
							name:    'menubar submenu interior'
							color:   cfg.color
							fill:    true
							padding: cfg.padding_submenu
							spacing: cfg.spacing_submenu
							sizing:  fill_fill
							content: menu_build(cfg, level + 1, item.submenu, window)
						),
					]
				)
				mi.content << submenu
			}
		}
		content << mi
	}
	return content
}

fn (cfg &MenubarCfg) amend_layout_menubar(mut node Layout, mut w Window) {
	// If the menubar does not have focus, it can't have a selected menu-item.
	if !w.is_focus(cfg.id_focus) {
		w.view_state.menu_state[cfg.id_focus] = ''
		return
	}
}

fn (cfg &MenubarCfg) on_hover_submenu(mut node Layout, mut _ Event, mut w Window) {
	// When the mouse moves outside a submenu it should unselect the
	// item in the submenu. This is a subtle behavior in mouse/menu
	// interactions I never noticed until designing this. To unselect
	// the item in the submenu you select teh submenu's parent menu item.
	// The parent menu-item id is the id of the submenu. In addition,
	// the unselect logic is only triggered when the menu item is a leaf
	// item. We know this because the selected menu item has no submenu.
	//
	// This is hard to follow because there are two trees involved. The
	// MenubarCfg tree and the Layout tree.
	id_selected := w.view_state.menu_state[cfg.id_focus]
	has_selected := descendant_has_id(node, id_selected)
	if has_selected {
		ctx := w.context()
		if !node.shape.point_in_shape(f32(ctx.mouse_pos_x), f32(ctx.mouse_pos_y)) {
			if mi_cfg := find_menu_item_cfg(cfg.items, id_selected) {
				if mi_cfg.submenu.len == 0 {
					w.view_state.menu_state[cfg.id_focus] = node.shape.id
				}
			}
		}
	}
}

fn descendant_has_id(node Layout, id string) bool {
	if node.shape.id == id {
		return true
	}
	for child in node.children {
		if descendant_has_id(child, id) {
			return true
		}
	}
	return false
}

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
