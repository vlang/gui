import gui

// Switching between different views
// =================================
// Changing views is as easy as `window.update_view(some_view)`.
// No worries about UI thread contentions.

fn main() {
	mut window := gui.window(
		width:   300
		height:  300
		on_init: fn (mut w gui.Window) {
			w.update_view(page_one)
			w.set_id_focus(1)
		}
	)
	window.run()
}

fn page(content []gui.View, window &gui.Window) gui.View {
	w, h := window.window_size()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
		content: content
	)
}

fn page_one(window &gui.Window) gui.View {
	return page([
		gui.text(text: 'Page One', text_style: gui.theme().b1),
		gui.button(
			id_focus:       1
			padding_border: gui.padding_two
			content:        [gui.text(text: 'next >>')]
			on_click:       fn (_ &gui.ButtonCfg, _ &gui.Event, mut w gui.Window) bool {
				w.update_view(page_two)
				w.set_id_focus(1)
				return true // true says click was handled
			}
		),
	], window)
}

fn page_two(window &gui.Window) gui.View {
	return page([
		gui.text(text: 'Page Two', text_style: gui.theme().b1),
		gui.button(
			id_focus:       1
			padding_border: gui.padding_two
			content:        [gui.text(text: '<< previous')]
			on_click:       fn (_ &gui.ButtonCfg, _ &gui.Event, mut w gui.Window) bool {
				w.update_view(page_one)
				w.set_id_focus(1)
				return true // true says click was handled
			}
		),
	], window)
}
