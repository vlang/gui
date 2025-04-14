import gui
import math

struct App {
pub mut:
	clicks int
	light  bool
}

fn main() {
	mut window := gui.window(
		title:   'Buttons'
		state:   &App{}
		width:   325
		height:  375
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
			w.set_id_focus(1)
		}
	)
	window.run()
}

fn main_view(mut window gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[App]()
	button_text := '${app.clicks} Clicks Given'
	button_width := window.get_text_width('XXX Clicks Given', gui.theme().n3) +
		gui.theme().button_style.padding.width() + gui.theme().padding_small.width()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		padding: gui.padding(0, 5, 5, 5)
		spacing: gui.spacing_medium
		h_align: .center
		v_align: .middle
		content: [
			gui.column(
				content: [
					button_change_theme(app),
					button_row('Plain ole button', gui.button(
						min_width: button_width
						max_width: button_width
						content:   [
							gui.text(text: button_text),
						]
						on_click:  click_handler
					)),
					button_row('Disabled button', gui.button(
						min_width: button_width
						max_width: button_width
						disabled:  true
						content:   [
							gui.text(text: button_text),
						]
						on_click:  click_handler
					)),
					button_row('With border', gui.button(
						min_width:      button_width
						max_width:      button_width
						content:        [
							gui.text(text: button_text),
						]
						padding_border: gui.padding_two
						on_click:       click_handler
					)),
					button_row('With focus border', gui.button(
						id_focus:       1
						min_width:      button_width
						max_width:      button_width
						content:        [
							gui.text(text: button_text),
						]
						padding_border: gui.padding_two
						on_click:       click_handler
					)),
					button_row('With detached border', gui.button(
						min_width:      button_width
						max_width:      button_width
						content:        [
							gui.text(text: button_text),
						]
						fill_border:    false
						padding_border: gui.theme().padding_small
						on_click:       click_handler
					)),
					button_row('With other content', gui.button(
						id:             'With progress bar'
						min_width:      button_width
						max_width:      button_width
						color:          gui.rgb(195, 105, 0)
						color_hover:    gui.rgb(195, 105, 0)
						color_click:    gui.rgb(205, 115, 0)
						padding_border: gui.pad_4(2)
						color_border:   gui.rgb(160, 160, 160)
						padding:        gui.padding_medium
						v_align:        .middle
						content:        [
							gui.text(text: '${app.clicks}'),
							gui.progress_bar(
								width:   75
								height:  10
								percent: f32(math.fmod(f64(app.clicks) / 25.0, 1.0))
							),
						]
						on_click:       click_handler
					)),
				]
			),
		]
	)
}

fn button_row(label string, button gui.View) gui.View {
	return gui.row(
		padding: gui.padding_none
		v_align: .middle
		content: [
			gui.row(
				min_width: 150
				max_width: 150
				padding:   gui.padding_none
				content:   [gui.text(text: label, wrap: true)]
			),
			button,
		]
	)
}

fn click_handler(_ &gui.ButtonCfg, _ &gui.Event, mut w gui.Window) bool {
	mut app := w.state[App]()
	app.clicks += 1
	w.set_id_focus(1)
	return true
}

fn button_change_theme(app &App) gui.View {
	return gui.row(
		h_align: .right
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			gui.button(
				padding:  gui.padding(1, 5, 1, 5)
				content:  [
					gui.text(
						text: if app.light { '●' } else { '○' }
					),
				]
				on_click: fn (_ &gui.ButtonCfg, _ &gui.Event, mut w gui.Window) bool {
					mut app := w.state[App]()
					app.light = !app.light
					w.set_theme(if app.light { gui.theme_light } else { gui.theme_dark })
					w.set_id_focus(1)
					return true
				}
			),
		]
	)
}
