module main

import gui
import gx

@[heap]
struct AppState {
pub mut:
	name        string
	other_input string
	click_count int
}

fn main() {
	mut window := gui.window(
		state:    &AppState{}
		title:    'test layout'
		width:    700
		height:   400
		bg_color: gx.rgb(0x30, 0x30, 0x30)
		on_init:  fn (mut w gui.Window) {
			w.update_view(main_view)
			w.set_id_focus(1)
		}
	)
	window.run()
}

fn main_view(w &gui.Window) gui.View {
	text_style := gx.TextCfg{
		color: gx.white
	}
	text_style_blue := gx.TextCfg{
		color: gx.light_blue
	}
	text_style_large := gx.TextCfg{
		...text_style
		size: 20
	}

	mut state := w.state[AppState]()
	width, height := w.window_size()

	return gui.row(
		width:    width
		height:   height
		fill:     true
		color:    gx.dark_blue
		sizing:   gui.fixed_fixed
		children: [
			gui.column(
				padding:  gui.padding_none
				sizing:   gui.fit_flex
				children: [
					gui.rectangle(
						width:  75
						height: 50
						fill:   true
						color:  gx.purple
					),
					gui.rectangle(
						width:  75
						height: 50
						sizing: gui.fit_flex
						color:  gui.transparent
					),
					gui.rectangle(
						width:  75
						height: 50
						fill:   true
						color:  gx.green
					),
				]
			),
			gui.row(
				id:       'orange'
				color:    gx.orange
				sizing:   gui.flex_flex
				children: [
					gui.column(
						sizing:   gui.flex_flex
						fill:     true
						color:    gx.rgb(0x30, 0x30, 0x30)
						children: [
							gui.rectangle(
								id:     'rect'
								width:  25
								height: 25
								color:  gx.orange
							),
							gui.rectangle(
								width:  25
								height: 25
								color:  gx.orange
							),
							gui.row(
								sizing:   gui.flex_fit
								color:    gx.white
								children: [
									gui.text(
										text:  'Hello world!'
										style: text_style_large
										wrap:  true
									),
								]
							),
							gui.text(
								text:  'This is text'
								style: text_style
							),
							gui.text(
								wrap:  true
								style: text_style
								text:  'Embedded in a column with wrapping'
							),
							gui.button(
								id_focus: 1
								text:     'Button Text ${state.click_count}'
								on_click: fn (id string, me gui.MouseEvent, mut w gui.Window) {
									mut state := w.state[AppState]()
									state.click_count += 1
									w.update_window()
								}
							),
							// gui.input(
							// 	id_focus:        2
							// 	width:           150
							// 	text:            state.other_input
							// 	text_style:      text_style
							// 	wrap:            true
							// 	sizing:          gui.fixed_fit
							// 	on_text_changed: fn (_ &gui.InputCfg, s string, mut w gui.Window) {
							// 		mut state := w.state[AppState]()
							// 		state.other_input = s
							// 		w.update_window()
							// 	}
							// ),
						]
					),
					gui.rectangle(
						id:     'green'
						width:  25
						height: 25
						fill:   true
						sizing: gui.flex_flex
						color:  gx.dark_green
					),
				]
			),
			gui.column(
				width:    75
				height:   50
				fill:     true
				sizing:   gui.flex_flex
				color:    gx.rgb(0x30, 0x30, 0x30)
				children: [
					gui.input(
						id_focus:        3
						width:           150
						text:            state.name
						text_style:      text_style
						wrap:            true
						sizing:          gui.fixed_fit
						on_text_changed: fn (_ &gui.InputCfg, s string, mut w gui.Window) {
							mut state := w.state[AppState]()
							state.name = s
							w.update_window()
						}
					),
					gui.column(
						color:    gx.gray
						sizing:   gui.flex_fit
						children: [
							gui.text(
								text:  'keep_spaces = false'
								style: text_style_blue
							),
							gui.text(
								text:  state.name
								style: text_style
								wrap:  true
							),
						]
					),
					gui.column(
						color:    gx.gray
						sizing:   gui.flex_fit
						children: [
							gui.text(
								text:  'keep_spaces = true'
								style: text_style_blue
							),
							gui.text(
								text:        state.name
								style:       text_style
								wrap:        true
								keep_spaces: true
							),
						]
					),
				]
			),
			gui.column(
				padding:  gui.padding_none
				sizing:   gui.fit_flex
				children: [
					gui.rectangle(
						width:  75
						height: 50
						fill:   true
						color:  gx.orange
					),
					gui.rectangle(
						width:  75
						height: 50
						sizing: gui.fit_flex
						color:  gui.transparent
					),
					gui.rectangle(
						width:  75
						height: 50
						fill:   true
						color:  gx.yellow
					),
				]
			),
		]
	)
}
