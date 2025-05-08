module gui

@[heap]
pub struct MenubarCfg {
pub:
	id                     string
	id_menubar             u32 @[required]
	color                  Color = gui_theme.color_1
	color_border           Color = gui_theme.button_style.color_border
	disabled               bool
	invisible              bool
	sizing                 Sizing  = fill_fit
	width_submenu_min      f32     = 50
	width_submenu_max      f32     = 200
	padding                Padding = padding_two_three
	padding_border         Padding = padding_one
	padding_submenu        Padding = padding_two_five
	padding_submenu_border Padding = padding_one
	spacing                f32     = gui_theme.spacing_medium
	spacing_submenu        f32     = 1
	items                  []MenuItemCfg
}

pub fn (window &Window) menubar(cfg MenubarCfg) View {
	content := menu_build(cfg, 0, cfg.items, window)
	return row(
		id:        cfg.id
		color:     cfg.color_border
		fill:      true
		disabled:  cfg.disabled
		invisible: cfg.invisible
		padding:   cfg.padding_border
		sizing:    cfg.sizing
		content:   [
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
	id_selected := window.view_state.menu_state[cfg.id_menubar]
	sizing := if level == 0 { fit_fit } else { fill_fit }
	for item in items {
		item_cfg := MenuItemCfg{
			...item
			selected: item.id == id_selected
			sizing:   sizing
		}
		mut menu := menu_item(cfg, item_cfg)
		if item_cfg.selected || is_selected_in_tree(item_cfg.submenu, id_selected) {
			if item.submenu.len > 0 {
				submenu := column(
					min_width:      cfg.width_submenu_min
					max_width:      cfg.width_submenu_max
					fill:           true
					color:          cfg.color_border
					padding:        cfg.padding_submenu_border
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
