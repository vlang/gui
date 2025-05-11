module gui

pub const menu_separator_id = '__separator__'
pub const menu_subtitle_id = '__subtitle__'

// MenuItemCfg configures a menu-item.  Menu items are containers and are not limited
// to text. There are three types of menu items.
//
// - separator, if the separator field is true, a horizontal line separating menu items is rendered.
// - custom view, if a custom_view is supplied, it is rendered.
// - text only, for convienence, a text field is availble for the typical text only menu items.
//
// If all three types are specified only one is rendereed. The priority is separator, custom view, text only.
// Custom and text only menus can have a submenu.
//
// The optional action callback can be used to process menu clicks. There is also a catch-all
// action callback in [MenubarCfg](#MenubarCfg) that is called afterwards.
//
// It should go without saying, but menu-item id's need to be unique within a menubar config.
// This is neccesary so callbacks can identify which menu-item was clicked. It also is how
// the menubar determines which menu items are selected/highlighted.
@[heap]
pub struct MenuItemCfg {
	color_selected Color = gui_theme.menubar_style.color_selected
	sizing         Sizing
	radius         f32       = gui_theme.menubar_style.radius_menu_item
	spacing        f32       = gui_theme.menubar_style.spacing_submenu
	text_style     TextStyle = gui_theme.menubar_style.text_style
	disabled       bool
	selected       bool
pub:
	id          string @[required]
	text        string  = 'empty'
	padding     Padding = gui_theme.menubar_style.padding_menu_item
	submenu     []MenuItemCfg
	separator   bool
	action      fn (&MenuItemCfg, mut Event, mut Window) = unsafe { nil }
	custom_view ?View
}

fn menu_item(menubar_cfg MenubarCfg, item_cfg MenuItemCfg) View {
	return match item_cfg.separator {
		true {
			column(
				id:      item_cfg.id
				height:  item_cfg.text_style.size / 2
				fill:    true
				sizing:  fill_fit
				padding: padding_none
				v_align: .middle
				content: [
					rectangle(
						height: 1
						color:  gui_theme.color_5
						sizing: fill_fit
					),
				]
			)
		}
		else {
			mut content := []View{}
			if item_cfg.custom_view != none {
				content << item_cfg.custom_view
			} else {
				content << text(
					text:       item_cfg.text
					text_style: item_cfg.text_style
					wrap:       true
				)
			}
			column(
				id:           item_cfg.id
				cfg:          &item_cfg
				disabled:     item_cfg.disabled
				color:        if item_cfg.selected {
					item_cfg.color_selected
				} else {
					color_transparent
				}
				fill:         item_cfg.selected
				padding:      item_cfg.padding
				radius:       item_cfg.radius
				sizing:       item_cfg.sizing
				on_click:     menubar_cfg.menu_item_click
				spacing:      item_cfg.spacing
				amend_layout: menubar_cfg.amend_layout_item
				content:      content
			)
		}
	}
}

// menu_item_text is a convienence function for creating a simple text menu item
pub fn menu_item_text(id string, text string) MenuItemCfg {
	if id.len == 0 {
		panic("empty menu id's are invalid")
	}
	return MenuItemCfg{
		id:   id
		text: text
	}
}

// menu_separator is a convienence function for createing a menu separator
pub fn menu_separator() MenuItemCfg {
	return MenuItemCfg{
		id:        menu_separator_id
		separator: true
	}
}

// menu_subtitlemenu_submenu subtitles
pub fn menu_subtitle(text string) MenuItemCfg {
	return MenuItemCfg{
		id:       menu_subtitle_id
		text:     text
		disabled: true
	}
}

// menu_submenu is a convienence function for createing a menu with an
// arrow symbol indicating a submenu
pub fn menu_submenu(id string, txt string, submenu []MenuItemCfg) MenuItemCfg {
	return MenuItemCfg{
		id:          id
		submenu:     submenu
		custom_view: row(
			padding: padding_none
			sizing:  fill_fit
			spacing: theme().spacing_large
			content: [
				text(text: txt, text_style: gui_theme.menubar_style.text_style),
				row(
					h_align: .right
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

// menu_item_click, for such a short method, there is alot going on here in terms
// of state management, thus the many comments.
fn (menubar_cfg MenubarCfg) menu_item_click(cfg &MenuItemCfg, mut e Event, mut w Window) {
	// setting the focus to the menubar enables mouse hover hightlighting of menu items.
	// see amend_layout_item
	w.set_id_focus(menubar_cfg.id_focus)
	// Hightlight the menu item
	w.view_state.menu_state[menubar_cfg.id_focus] = cfg.id
	// Menu time action handler
	if cfg.action != unsafe { nil } {
		cfg.action(cfg, mut e, mut w)
	}
	// Common menubar action handler
	menubar_cfg.action(cfg.id, mut e, mut w)
	// if this is simple menu-item (no submenu) then clicking it
	// also closes the menu and removes focus.
	if cfg.submenu.len == 0 {
		w.set_id_focus(0)
		w.view_state.menu_state[menubar_cfg.id_focus] = ''
	}
}

fn (cfg &MenubarCfg) amend_layout_item(mut node Layout, mut w Window) {
	// Mouse hover logic is covered here. Once the **menubar** gains focus,
	// mouse-overs can change the selected menu-item. Note: Selection
	// incicates highlighting, not focus. This is key to understanding menus.
	ctx := w.context()
	if node.shape.point_in_shape(f32(ctx.mouse_pos_x), f32(ctx.mouse_pos_y)) {
		if w.dialog_cfg.visible && !node_in_dialog_layout(node) {
			return
		}
		if node.shape.id.len == 0 || node.shape.disabled || !w.is_focus(cfg.id_focus) {
			return
		}
		w.view_state.menu_state[cfg.id_focus] = node.shape.id
	}
}
