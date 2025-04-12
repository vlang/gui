import gui
import os.font

const text = '
Far far away, behind the word mountains, far from the countries Vokalia and Consonantia, there live the blind texts.

Separated they live in Bookmarksgrove right at the coast of the Semantics, a large language ocean.

A small river named Duden flows by their place and supplies it with the necessary regelialia.

It is a paradisematic country, in which roasted parts of sentences fly into your mouth.

Even the all-powerful Pointing has no control about the blind texts it is an almost unorthographic life. One day however a small line of blind text by the name of Lorem Ipsum decided to leave for the far World of Grammar.

The Big Oxmox advised her not to do so, because there were thousands of bad Commas, wild Question Marks and devious Semikoli, but the Little Blind Text didn’t listen.

She packed her seven versalia, put her initial into the belt and made herself on the way.

When she reached the first hills of the Italic Mountains, she had a last view back on the skyline of her hometown Bookmarksgrove, the headline of Alphabet Village and the subline of her own road, the Line Lane.

Pityful a rethoric question ran over her cheek, then'

@[heap]
struct App {
pub mut:
	light bool
}

fn main() {
	mut window := gui.window(
		state:   &App{}
		width:   400
		height:  600
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
			w.set_id_focus(1)
		}
	)
	println(font.default())
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[App]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		content: [
			top_row(app),
			gui.rectangle(height: 0.5, sizing: gui.fill_fixed),
			gui.row(
				padding: gui.padding_none
				sizing:  gui.fill_fill
				content: [
					scroll_column(1, text, window),
					scroll_column(2, text, window),
				]
			),
		]
	)
}

fn scroll_column(id u32, text string, window &gui.Window) gui.View {
	return gui.column(
		id_focus:    id // enables keyboard scrolling
		id_scroll_v: id
		color:       match window.is_focus(id) {
			true { gui.theme().button_style.color_border_focus }
			else { gui.theme().container_style.color }
		}
		padding:     gui.padding_small
		sizing:      gui.fill_fill
		content:     [
			gui.text(
				text:        text
				keep_spaces: true
				wrap:        true
			),
		]
	)
}

fn top_row(app &App) gui.View {
	return gui.row(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		v_align: .middle
		content: [
			gui.text(
				text:       'Scroll Demo'
				text_style: gui.theme().b1
			),
			gui.rectangle(
				sizing: gui.fill_fit
				color:  gui.color_transparent
			),
			theme_button(app),
		]
	)
}

fn theme_button(app &App) gui.View {
	return gui.button(
		id_focus:       3
		padding:        gui.padding(3, 4, 1, 4)
		padding_border: gui.padding_two
		content:        [
			gui.text(
				text: if app.light { '●' } else { '○' }
			),
		]
		on_click:       fn (_ &gui.ButtonCfg, _ &gui.Event, mut w gui.Window) bool {
			mut app := w.state[App]()
			app.light = !app.light
			theme := if app.light {
				gui.theme_light
			} else {
				gui.theme_dark
			}
			w.set_theme(theme)
			return true
		}
	)
}
