module gui

import datatypes

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
				content: menu_build(cfg, 1, cfg.items, mut window)
			),
		]
	)
}

fn menu_build(cfg MenubarCfg, level int, items []MenuItemCfg, mut window Window) []View {
	mut content := []View{}
	if window.view_state.menu_state[cfg.id_focus] == '' {
		window.view_state.menu_state[cfg.id_focus] = items[0].id
		window.set_id_focus(cfg.id_focus)
	}
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
							content: menu_build(cfg, level + 1, item.submenu, mut window)
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
