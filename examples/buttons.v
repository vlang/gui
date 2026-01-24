import gui
import math

// Buttons
// =============================
// Not so different than what you'll find in other frameworks with
// exception. Buttons are containers meaning you're not limited to
// only text.
//
// The theme button shows how easy it is to switch themes in GUI.
// GUI comes with a handful of themes, and an Icon set. Themes in
// GUI are powerful and granular. See the theme_designer.v program
// for more about themes.

struct ButtonsApp {
pub mut:
	clicks int
	light  bool
}

fn main() {
	mut window := gui.window(
		title:   'Buttons'
		state:   &ButtonsApp{}
		width:   400
		height:  375
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
			w.set_id_focus(1)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(mut window gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[ButtonsApp]()
	button_text := '${app.clicks} Clicks Given'
	b_width := f32(140)

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
						min_width: b_width
						max_width: b_width
						content:   [gui.text(text: button_text)]
						on_click:  click_handler
					)),
					button_row('Disabled button', gui.button(
						min_width: b_width
						max_width: b_width
						disabled:  true
						content:   [gui.text(text: button_text)]
						on_click:  click_handler
					)),
					button_row('With border', gui.button(
						min_width:      b_width
						max_width:      b_width
						content:        [gui.text(text: button_text)]
						border_width:   2

						on_click:       click_handler
					)),
					button_row('With focus border', gui.button(
						id_focus:       1
						min_width:      b_width
						max_width:      b_width
						content:        [gui.text(text: button_text)]
						border_width:   2

						on_click:       click_handler
					)),
					button_row('With detached border', gui.button(
						content:        [gui.text(text: button_text)]
						min_width:      b_width
						max_width:      b_width
						fill_border:    false
						border_width:   1

						on_click:       click_handler
					)),
					button_row('With other content', gui.button(
						id:             'With progress bar'
						min_width:      200
						max_width:      200
						color:          gui.rgb(195, 105, 0)
						color_hover:    gui.rgb(195, 105, 0)
						color_click:    gui.rgb(205, 115, 0)
						border_width:   2

						color_border:   gui.rgb(160, 160, 160)
						padding:        gui.padding_medium
						v_align:        .middle
						content:        [gui.text(text: '${app.clicks}', min_width: 25),
							gui.progress_bar(
								width:   75
								height:  gui.theme().text_style.size
								percent: f32(math.fmod(f64(app.clicks) / 25.0, 1.0))
							)]
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
		sizing:  gui.fill_fit
		v_align: .middle
		content: [
			gui.row(
				padding: gui.padding_none
				content: [gui.text(text: label, mode: .single_line)]
			),
			gui.row(sizing: gui.fill_fit),
			button,
		]
	)
}

fn click_handler(_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
	mut app := w.state[ButtonsApp]()
	app.clicks += 1
	w.set_id_focus(1)
}

fn button_change_theme(app &ButtonsApp) gui.View {
	return gui.row(
		h_align: .end
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			gui.toggle(
				text_select:   gui.icon_moon
				text_unselect: gui.icon_sunny_o
				text_style:    gui.theme().icon3
				padding:       gui.theme().padding_small
				select:        app.light
				on_click:      fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[ButtonsApp]()
					app.light = !app.light
					w.set_theme(if app.light { gui.theme_light } else { gui.theme_dark })
					w.set_id_focus(1)
				}
			),
		]
	)
}
