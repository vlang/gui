import gui

@[heap]
struct ColorPickerApp {
pub mut:
	color       gui.Color = gui.Color{
		r: 255
		g: 85
		b: 0
		a: 255
	}
	show_hsv    bool
	light_theme bool
}

fn main() {
	mut window := gui.window(
		title:   'Color Picker'
		state:   &ColorPickerApp{}
		width:   300
		height:  490
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[ColorPickerApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		padding: gui.theme().padding_medium
		spacing: gui.theme().spacing_medium
		content: [
			gui.row(
				v_align: .middle
				sizing:  gui.fit_fit
				padding: gui.padding_none
				spacing: gui.theme().spacing_medium
				content: [toggle_theme(app), toggle_hsv(app)]
			),
			gui.color_picker(
				id:              'picker'
				color:           app.color
				id_focus:        10
				show_hsv:        app.show_hsv
				on_color_change: fn (c gui.Color, mut _ gui.Event, mut w gui.Window) {
					mut a := w.state[ColorPickerApp]()
					a.color = c
				}
			),
		]
	)
}

fn toggle_hsv(app &ColorPickerApp) gui.View {
	return gui.switch(
		label:    'HSV'
		select:   app.show_hsv
		on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			mut a := w.state[ColorPickerApp]()
			a.show_hsv = !a.show_hsv
		}
	)
}

fn toggle_theme(app &ColorPickerApp) gui.View {
	return gui.toggle(
		text_select:   gui.icon_moon
		text_unselect: gui.icon_sunny_o
		text_style:    gui.theme().icon3
		padding:       gui.theme().padding_small
		select:        app.light_theme
		on_click:      fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			mut app := w.state[ColorPickerApp]()
			app.light_theme = !app.light_theme
			theme := if app.light_theme {
				gui.theme_light_bordered
			} else {
				gui.theme_dark_bordered
			}
			w.set_theme(theme)
		}
	)
}
