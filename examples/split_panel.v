import gui

// Split Panel Example
// =============================
// Gui does not hava a "splitter" view (that may change) but it
// can be done simply by using a button (or row/column if you want
// more control over appearance) and some mouse_move logic. The only
// width that needs to be controlled is the 'A' panel. The splitter
// button and 'B' panel are positioned/sized by the layout engine.

@[heap]
struct SplitPanelApp {
pub mut:
	a_width f32 = 125
}

fn main() {
	mut window := gui.window(
		state:   &SplitPanelApp{}
		width:   300
		height:  300
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[SplitPanelApp]()

	return gui.row(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		spacing: 1
		content: [
			gui.column(
				id:      'A'
				width:   app.a_width
				fill:    true
				color:   gui.theme().color_interior
				sizing:  gui.fixed_fill
				h_align: .center
				v_align: .middle
				clip:    true
				content: [
					gui.text(text: 'Panel A'),
				]
			),
			gui.button(
				width:    5
				sizing:   gui.fit_fill
				padding:  gui.padding_none
				on_click: split_click
			),
			gui.column(
				fill:    true
				color:   gui.theme().color_interior
				sizing:  gui.fill_fill
				h_align: .center
				v_align: .middle
				content: [
					gui.text(text: 'Panel B'),
				]
			),
		]
	)
}

fn split_click(cfg &gui.Layout, mut e gui.Event, mut w gui.Window) {
	w.mouse_lock(gui.MouseLockCfg{
		mouse_move: fn (layout &gui.Layout, mut e gui.Event, mut w gui.Window) {
			// The layout here is first layout in the view. This is because
			// the handler here has nothing to do with button per se.
			// In this case, the button is not even needed after the
			// initial click event. The panel that needs to be resized
			// is the 'A' panel. The button and 'B' panel require no
			// additional work because the layout engine will position
			// and size them for you.
			if a_layout := layout.find_layout(fn (n gui.Layout) bool {
				return n.shape.id == 'A'
			})
			{
				mut app := w.state[SplitPanelApp]()
				width, _ := w.window_size()
				app.a_width = gui.f32_clamp(a_layout.shape.width + e.mouse_dx, 20, width - 50)
			}
		}
		mouse_up:   fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
			w.mouse_unlock()
		}
	})
}
