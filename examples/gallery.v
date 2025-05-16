import gui

// Gallery
// =============================
// WIP

@[heap]
struct GalleryApp {
}

fn main() {
	mut window := gui.window(
		state:   &GalleryApp{}
		width:   500
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
	// app := window.state[GalleryApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		content: [
			gui.row(
				padding: gui.padding_none
				sizing:  gui.fill_fill
				content: [
					control(window),
					gallery(window),
				]
			),
		]
	)
}

fn control(w &gui.Window) gui.View {
	return gui.column(
		fill:    true
		color:   gui.theme().color_1
		sizing:  gui.fit_fill
		content: [
			gui.text(text: 'List of controls here...'),
		]
	)
}

fn gallery(w &gui.Window) gui.View {
	return gui.column(
		fill:    true
		color:   gui.theme().color_1
		sizing:  gui.fill_fill
		content: [
			buttons(w),
		]
	)
}

fn view_title(label string) gui.View {
	return gui.column(
		spacing: 0
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			gui.text(text: label, text_style: gui.theme().b2),
			line(),
		]
	)
}

fn line() gui.View {
	return gui.row(
		height:  1
		sizing:  gui.fill_fit
		fill:    true
		padding: gui.padding_none
		color:   gui.theme().color_5
	)
}

fn buttons(w &gui.Window) gui.View {
	return gui.column(
		sizing:  gui.fill_fit
		content: [
			view_title('Buttons'),
			gui.row(
				sizing:  gui.fill_fit
				padding: gui.padding_none
				content: [
					gui.button(content: [gui.text(text: 'Plain Button')], on_click: button_click),
				]
			),
		]
	)
}

fn button_click(_ &gui.ButtonCfg, mut e gui.Event, mut w gui.Window) {
	e.is_handled = true
}
