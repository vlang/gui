import gui

// Sample Material Design icons (24x24 viewBox)
const icon_home = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z"/></svg>'
const icon_settings = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M19.14 12.94c.04-.31.06-.63.06-.94 0-.31-.02-.63-.06-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.04.31-.06.63-.06.94s.02.63.06.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z"/></svg>'
const icon_star = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"/></svg>'
const icon_heart = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg>'
const icon_check = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>'

fn main() {
	mut window := gui.window(
		title:   'SVG Demo'
		width:   600
		height:  600
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		padding: gui.theme().padding_large
		spacing: 20
		content: [
			gui.text(text: 'SVG Icon Demo', text_style: gui.theme().b1),
			// Row of icons at default size (24x24)
			gui.text(text: 'Default size (24x24):', text_style: gui.theme().b2),
			gui.row(
				spacing: 10
				content: [
					gui.svg(svg_data: icon_home, width: 24, height: 24, color: gui.white),
					gui.svg(svg_data: icon_settings, width: 24, height: 24, color: gui.white),
					gui.svg(svg_data: icon_star, width: 24, height: 24, color: gui.white),
					gui.svg(svg_data: icon_heart, width: 24, height: 24, color: gui.white),
					gui.svg(svg_data: icon_check, width: 24, height: 24, color: gui.white),
				]
			),
			// Row with color overrides
			gui.text(text: 'With color overrides:', text_style: gui.theme().b2),
			gui.row(
				spacing: 10
				content: [
					gui.svg(svg_data: icon_home, width: 32, height: 32, color: gui.blue),
					gui.svg(svg_data: icon_settings, width: 32, height: 32, color: gui.gray),
					gui.svg(svg_data: icon_star, width: 32, height: 32, color: gui.yellow),
					gui.svg(svg_data: icon_heart, width: 32, height: 32, color: gui.red),
					gui.svg(svg_data: icon_check, width: 32, height: 32, color: gui.green),
				]
			),
			// Larger icons
			gui.text(text: 'Scaled up (48x48, 64x64):', text_style: gui.theme().b2),
			gui.row(
				spacing: 20
				v_align: .middle
				content: [
					gui.svg(svg_data: icon_home, width: 48, height: 48, color: gui.cyan),
					gui.svg(svg_data: icon_star, width: 64, height: 64, color: gui.orange),
					gui.svg(svg_data: icon_heart, width: 48, height: 48, color: gui.pink),
				]
			),
			// Clickable icon
			gui.text(text: 'Clickable icon:', text_style: gui.theme().b2),
			gui.svg(
				svg_data: icon_settings
				width:    40
				height:   40
				color:    gui.light_gray
				on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
					w.dialog(
						align_buttons: .end
						dialog_type:   .message
						title:         'Settings'
						body:          'Settings icon clicked!'
					)
				}
			),
		]
	)
}
