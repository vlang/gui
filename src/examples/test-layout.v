module main

import gui

@[heap]
struct AppState {
pub mut:
	name        string
	other_input string
	click_count int
}

fn main() {
	mut window := gui.window(
		state:   &AppState{
			name:
				'Lorem Ipsum is simply        dummy text of the printing and typesetting industry. ' +
				"Lorem Ipsum has been       the industry's standard dummy text ever since the 1500s, " +
				'when an unknown printer    took a galley of type and scrambled it to make a type ' +
				'specimen book.'
		}
		title:   'test layout'
		width:   700
		height:  600
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
			w.set_id_focus(2)
		}
	)
	window.run()
}

fn main_view(w &gui.Window) gui.View {
	mut state := w.state[AppState]()
	width, height := w.window_size()

	text_style_blue := gui.TextStyle{
		...gui.theme().b4
		color: gui.rgb(100, 149, 237)
	}

	return gui.row(
		width:   width
		height:  height
		sizing:  gui.fixed_fixed
		color:   gui.dark_blue
		fill:    true
		content: [
			gui.column(
				padding: gui.padding_none
				sizing:  gui.fit_fill
				content: [
					gui.rectangle(
						width:  75
						height: 50
						fill:   true
						color:  gui.purple
					),
					gui.rectangle(
						width:  75
						sizing: gui.fit_fill
						color:  gui.color_transparent
					),
					gui.rectangle(
						width:  75
						height: 50
						fill:   true
						color:  gui.green
					),
				]
			),
			gui.row(
				id:      'orange'
				text:    ' orange  '
				color:   gui.orange
				sizing:  gui.fill_fill
				content: [
					gui.column(
						id:      'col'
						sizing:  gui.fill_fill
						fill:    true
						color:   gui.rgb(0x30, 0x30, 0x30)
						spacing: gui.theme().spacing_large
						content: [
							gui.row(
								color:   gui.white
								content: [
									gui.text(
										text:       'Hello world!'
										text_style: gui.theme().b2
										wrap:       true
									),
								]
							),
							gui.text(
								text: 'Embedded in a column with wrapping'
								wrap: true
							),
							gui.button(
								id_focus:       1
								padding_border: gui.padding_two
								content:        [
									gui.text(text: 'Button Text ${state.click_count}'),
								]
								on_click:       fn (_ &gui.ButtonCfg, mut _ gui.Event, mut w gui.Window) {
									mut state := w.state[AppState]()
									state.click_count += 1
								}
							),
							gui.row(
								v_align: .middle
								padding: gui.padding_none
								content: [
									gui.text(
										text: 'label'
									),
									gui.input(
										id_focus:        2
										width:           100
										sizing:          gui.fixed_fit
										text:            state.other_input
										wrap:            false
										padding_border:  gui.padding_two
										on_text_changed: fn (_ &gui.InputCfg, s string, mut w gui.Window) {
											mut state := w.state[AppState]()
											state.other_input = s
										}
									),
								]
							),
							gui.text(
								text: 'progress bar'
							),
							gui.progress_bar(
								percent: 0.35
								sizing:  gui.fill_fit
							),
						]
					),
					gui.rectangle(
						width:  25
						height: 25
						fill:   true
						sizing: gui.fill_fill
						color:  gui.dark_green
					),
				]
			),
			gui.column(
				fill:    true
				sizing:  gui.fill_fill
				color:   gui.rgb(0x30, 0x30, 0x30)
				content: [
					gui.input(
						id_focus:        3
						width:           250
						text:            state.name
						wrap:            true
						sizing:          gui.fixed_fit
						padding_border:  gui.padding_two
						on_text_changed: fn (_ &gui.InputCfg, s string, mut w gui.Window) {
							mut state := w.state[AppState]()
							state.name = s
						}
					),
					gui.column(
						color:   gui.gray
						sizing:  gui.fill_fit
						content: [
							gui.text(
								text:       'keep_spaces = false'
								text_style: text_style_blue
							),
							gui.text(
								id_focus:    6
								text:        state.name
								wrap:        true
								keep_spaces: false
							),
						]
					),
					gui.column(
						color:   gui.gray
						sizing:  gui.fill_fit
						content: [
							gui.text(
								text:       'keep_spaces = true'
								text_style: text_style_blue
							),
							gui.text(
								id_focus:    7
								text:        state.name
								wrap:        true
								keep_spaces: true
							),
						]
					),
				]
			),
			gui.column(
				padding: gui.padding_none
				sizing:  gui.fit_fill
				content: [
					gui.rectangle(
						width:  75
						height: 50
						fill:   true
						color:  gui.orange
					),
					gui.rectangle(
						width:  75
						sizing: gui.fit_fill
						color:  gui.color_transparent
					),
					gui.rectangle(
						width:  75
						height: 50
						fill:   true
						color:  gui.yellow
					),
				]
			),
		]
	)
}
