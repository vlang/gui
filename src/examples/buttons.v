import gui
import gg
import gx
import math

struct App {
pub mut:
	clicks int
}

fn main() {
	mut window := gui.window(
		title:   'Buttons'
		state:   &App{}
		width:   325
		height:  300
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[App]()
	button_text := '${app.clicks} Clicks Given'
	button_width := 125

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		spacing: gui.spacing_medium
		content: [
			button_row('Plain ole button', gui.button(
				min_width: button_width
				max_width: button_width
				content:   [gui.text(text: button_text)]
				on_click:  fn (_ &gui.ButtonCfg, _ &gg.Event, mut w gui.Window) bool {
					mut app := w.state[App]()
					app.clicks += 1
					return true
				}
			)),
			button_row('With border', gui.button(
				min_width:      button_width
				max_width:      button_width
				content:        [gui.text(text: button_text)]
				padding_border: gui.pad_4(1)
				on_click:       fn (_ &gui.ButtonCfg, _ &gg.Event, mut w gui.Window) bool {
					mut app := w.state[App]()
					app.clicks += 1
					return true
				}
			)),
			button_row('With thick border', gui.button(
				min_width:      button_width
				max_width:      button_width
				content:        [gui.text(text: button_text)]
				padding_border: gui.pad_4(3)
				on_click:       fn (_ &gui.ButtonCfg, _ &gg.Event, mut w gui.Window) bool {
					mut app := w.state[App]()
					app.clicks += 1
					return true
				}
			)),
			button_row('With detached border', gui.button(
				min_width:      button_width
				max_width:      button_width
				content:        [gui.text(text: button_text)]
				fill_border:    false
				padding_border: gui.pad_4(5)
				on_click:       fn (_ &gui.ButtonCfg, _ &gg.Event, mut w gui.Window) bool {
					mut app := w.state[App]()
					app.clicks += 1
					return true
				}
			)),
			button_row('With progress bar', gui.button(
				id:             'With progress bar'
				min_width:      button_width
				max_width:      button_width
				color:          gx.rgb(195, 105, 0)
				color_hover:    gx.rgb(195, 105, 0)
				color_click:    gx.rgb(205, 115, 0)
				color_border:   gx.white
				padding_border: gui.pad_4(1)
				padding:        gui.padding_medium
				v_align:        .middle
				content:        [gui.text(text: '${app.clicks}'),
					gui.progress_bar(
						width:   75
						height:  10
						percent: f32(math.fmod(f64(app.clicks) / 25.0, 1.0))
					)]
				on_click:       fn (_ &gui.ButtonCfg, _ &gg.Event, mut w gui.Window) bool {
					mut app := w.state[App]()
					app.clicks += 1
					return true
				}
			)),
		]
	)
}

fn button_row(label string, button gui.View) gui.View {
	return gui.row(
		padding: gui.padding_none
		v_align: .middle
		content: [
			gui.text(text: label, min_width: 150),
			button,
		]
	)
}
