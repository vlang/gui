module main

import gui

fn main() {
	mut window := gui.window(
		title:   'Overflow Panel Demo'
		width:   600
		height:  200
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.run()
}

fn main_view(mut window gui.Window) gui.View {
	w, h := window.window_size()
	items := [
		item('home', 'Home'),
		item('edit', 'Edit'),
		item('view', 'View'),
		item('tools', 'Tools'),
		item('help', 'Help'),
		item('settings', 'Settings'),
		item('about', 'About'),
	]
	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		padding: gui.pad_all(20)
		spacing: 10
		content: [
			gui.text(text: 'Resize the window to see overflow behavior.'),
			window.overflow_panel(gui.OverflowPanelCfg{
				id:       'toolbar'
				id_focus: 1
				items:    items
			}),
		]
	)
}

fn item(id string, label string) gui.OverflowItem {
	return gui.OverflowItem{
		id:     id
		text:   label
		view:   gui.button(
			content: [
				gui.text(text: label),
			]
		)
		action: fn (_ &gui.MenuItemCfg, mut e gui.Event, mut _ gui.Window) {
			e.is_handled = true
		}
	}
}
