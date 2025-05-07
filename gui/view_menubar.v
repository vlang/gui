module gui

@[heap]
pub struct MenubarCfg {
pub:
	id             string
	id_menubar     u32 @[required]
	color          Color = gui_theme.color_1
	color_border   Color = gui_theme.button_style.color_border
	disabled       bool
	invisible      bool
	sizing         Sizing  = fill_fit
	padding        Padding = padding_two_three
	padding_border Padding = padding_one
	spacing        f32     = gui_theme.spacing_medium
	items          []MenuItemCfg
}

pub fn (window &Window) menubar(cfg MenubarCfg) View {
	content := menu_build(cfg, true, cfg.items, window)
	return row(
		id:        cfg.id
		color:     cfg.color
		disabled:  cfg.disabled
		fill:      true
		invisible: cfg.invisible
		padding:   cfg.padding
		sizing:    cfg.sizing
		spacing:   cfg.spacing
		content:   content
	)
}

fn menu_build(cfg MenubarCfg, top_level bool, items []MenuItemCfg, window &Window) []View {
	mut content := []View{}
	id_selected := window.view_state.menu_state[cfg.id_menubar]
	for item in items {
		item_cfg := match item.id == id_selected {
			true {
				MenuItemCfg{
					...item
					selected: true
				}
			}
			else {
				item
			}
		}
		if mut menu := menu_item(cfg, item_cfg) {
			content << menu
			if item_cfg.selected || is_selected_in_tree(item_cfg.submenu, id_selected) {
				submenu := column(
					fill:          true
					float:         true
					color:         cfg.color_border
					padding:       cfg.padding_border
					float_anchor:  .bottom_right
					float_tie_off: .top_left
					content:       [
						column(
							color:   cfg.color
							fill:    true
							padding: cfg.padding
							content: menu_build(cfg, false, item.submenu, window)
						),
					]
				)
				menu.content << submenu
			}
		}
	}
	return content
}

fn is_selected_in_tree(submenu []MenuItemCfg, id_selected string) bool {
	if submenu.len > 0 {
		for menu in submenu {
			if menu.id == id_selected {
				return true
			}
			return is_selected_in_tree(menu.submenu, id_selected)
		}
	}
	return false
}
