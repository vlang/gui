module gui

pub const menu_separator_id = '__separator__'
pub const menu_subtitle_id = '__subtitle__'

// MenuItemCfg configures a single menu item, which may be a separator,
// a custom view, or a simple text item. Menu items may contain a submenu.
// Only one of separator, custom_view, or text is rendered, in that priority order.
@[minify]
pub struct MenuItemCfg {
	color_select Color     = gui_theme.menubar_style.color_select
	text_style   TextStyle = gui_theme.menubar_style.text_style
	sizing       Sizing
	radius       f32 = gui_theme.menubar_style.radius_menu_item
	spacing      f32 = gui_theme.menubar_style.spacing_submenu
	disabled     bool
	selected     bool
pub:
	id          string @[required]
	text        string  = 'empty'
	padding     Padding = gui_theme.menubar_style.padding_menu_item
	action      fn (&MenuItemCfg, mut Event, mut Window) = unsafe { nil }
	submenu     []MenuItemCfg
	custom_view ?View
	separator   bool
}

// menu_item builds a concrete View for a MenuItemCfg, handling
// separators, custom views, text-only items, and submenu-capable items.
fn menu_item(menubar_cfg MenubarCfg, item_cfg MenuItemCfg) View {
	return match item_cfg.separator {
		true {
			if item_cfg.action != unsafe { nil } {
				panic('Menu separator action != nil')
			}
			// Render a visual separator as a thin horizontal line.
			column(
				name:     'menu_item separator'
				id:       item_cfg.id
				height:   item_cfg.text_style.size / 2
				sizing:   fill_fit
				padding:  padding_none
				v_align:  .middle
				on_click: menubar_cfg.menu_item_click(item_cfg)
				content:  [
					rectangle(
						height: 1
						color:  gui_theme.color_active
						sizing: fill_fit
					),
				]
			)
		}
		else {
			// Normal menu item with either a custom view or text.
			mut content := []View{cap: 1}
			color := if item_cfg.selected {
				item_cfg.color_select
			} else {
				color_transparent
			}
			if item_cfg.custom_view != none {
				content << item_cfg.custom_view
			} else {
				content << text(
					text:       item_cfg.text
					text_style: item_cfg.text_style
					mode:       .wrap
				)
			}
			// Extract id_focus for optimized closure capture
			id_focus := menubar_cfg.id_focus
			column(
				name:         'menu_item'
				id:           item_cfg.id
				disabled:     item_cfg.disabled
				color:        color
				color_border: color
				size_border:  1
				padding:      item_cfg.padding
				radius:       item_cfg.radius
				sizing:       item_cfg.sizing
				on_click:     menubar_cfg.menu_item_click(item_cfg)
				spacing:      item_cfg.spacing
				on_hover:     fn [id_focus] (mut layout Layout, mut _ Event, mut w Window) {
					// Exit if disabled, unfocused, or keyboard navigation overrides hover.
					if layout.shape.id.len == 0 || layout.shape.disabled || !w.is_focus(id_focus)
						|| w.view_state.menu_key_nav {
						return
					}
					// Set the currently hovered menu item as selected.
					w.view_state.menu_state.set(id_focus, layout.shape.id)
				}
				content:      content
			)
		}
	}
}

// menu_item_text creates a simple text-only menu item using an id and label
pub fn menu_item_text(id string, text string) MenuItemCfg {
	if id.is_blank() {
		panic("blank menu id's are invalid")
	}
	return MenuItemCfg{
		id:   id
		text: text
	}
}

// menu_separator creates a menu separator item with a standard id
pub fn menu_separator() MenuItemCfg {
	return MenuItemCfg{
		id:        menu_separator_id
		separator: true
	}
}

// menu_subtitle creates a non-interactive subtitle item, typically
// used as a label or grouping indicator within a menu
pub fn menu_subtitle(text string) MenuItemCfg {
	return MenuItemCfg{
		id:       menu_subtitle_id
		text:     text
		disabled: true
	}
}

// menu_submenu creates a menu item that displays text plus a right arrow,
// indicating the presence of a submenu
pub fn menu_submenu(id string, txt string, submenu []MenuItemCfg) MenuItemCfg {
	return MenuItemCfg{
		id:          id
		submenu:     submenu
		custom_view: row(
			padding: padding_none
			sizing:  fill_fit
			spacing: gui_theme.spacing_large
			content: [
				text(text: txt, text_style: gui_theme.menubar_style.text_style),
				row(
					name:    'menu_submenu'
					h_align: .end
					sizing:  fill_fit
					padding: padding_none
					content: [
						text(
							text:       '›'
							text_style: gui_theme.menubar_style.text_style
						),
					]
				),
			]
		)
	}
}

// menu_item_click transforms a MenuItemCfg into an on_click handler that
// updates focus, selection state, invokes callbacks, and closes menus
// for items without submenus. Captures minimal values to reduce closure size.
fn (cfg MenubarCfg) menu_item_click(item_cfg MenuItemCfg) fn (&Layout, mut Event, mut Window) {
	// Extract minimal values needed for the handler
	id_focus := cfg.id_focus
	item_id := item_cfg.id
	item_action := item_cfg.action
	menubar_action := cfg.action
	has_submenu := item_cfg.submenu.len > 0
	is_top_level := item_cfg.id in cfg.items.map(it.id)

	// Note: item_cfg is still captured because item_action callback expects &MenuItemCfg parameter
	return fn [id_focus, item_id, item_action, menubar_action, has_submenu, is_top_level, item_cfg] (_ &Layout, mut e Event, mut w Window) {
		// Give focus to the menubar to enable hover-driven selection.
		w.set_id_focus(id_focus)

		if !is_selectable_menu_id(item_id) {
			e.is_handled = true
			return
		}

		// Mark this item as the selected/highlighted one.
		w.view_state.menu_state.set(id_focus, item_id)

		// Item-specific action callback.
		if item_action != unsafe { nil } {
			item_action(item_cfg, mut e, mut w)
		}

		// Menubar-level action callback.
		if menubar_action != unsafe { nil } && !e.is_handled {
			menubar_action(item_id, mut e, mut w)
		}

		// If the item has no submenu and is not top-level, clicking collapses the menu.
		if !has_submenu && !is_top_level {
			w.set_id_focus(0)
			w.view_state.menu_state.set(id_focus, '')
		} else {
			w.view_state.menu_state.set(id_focus, item_id)
		}

		e.is_handled = true
	}
}
