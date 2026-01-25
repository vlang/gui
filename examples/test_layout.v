import gui

// test layout
// =================================
// This is an odd ball collection of layouts I used while developing GUI.
// It's meant to torture-test the layout engine to expose bugs.

@[heap]
struct AppState {
pub mut:
	name        string
	other_input string
	click_count int
}

fn main() {
	mut window := gui.window(
		state:        &AppState{
			name:
				'Lorem Ipsum is simply        dummy text of the printing and typesetting industry.' +
				"Lorem Ipsum has been       the industry's\nstandard in dummy text ever since the 1500s, " +
				'when an unknown printer    took a galley of type and scrambled it to make a type ' +
				'specimen book.'
		}
		title:        'test layout'
		width:        800
		height:       700
		cursor_blink: true
		on_init:      fn (mut w gui.Window) {
			w.update_view(main_view)
			w.set_id_focus(2)
		}
	)
	window.set_theme(gui.theme_blue_bordered)
	window.run()
}

fn main_view(w &gui.Window) gui.View {
	mut state := w.state[AppState]()
	width, height := w.window_size()
	app := w.state[AppState]()

	return gui.row(
		width:   width
		height:  height
		sizing:  gui.fixed_fixed
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
				title:   ' orange  '
				color:   gui.orange
				sizing:  gui.fill_fill
				content: [
					gui.column(
						id:      'col'
						color:   gui.theme().color_panel
						sizing:  gui.fill_fill
						fill:    true
						spacing: gui.theme().spacing_large
						content: [
							gui.row(
								color:   gui.white
								content: [
									gui.text(
										text:       'Hello world!'
										text_style: gui.theme().b2
										mode:       .wrap
									),
								]
							),
							gui.text(
								id_focus: 8
								text:     'Embedded in a column with wrapping'
								mode:     .wrap
							),
							gui.button(
								id_focus:     1
								border_width: 2

								content:  [
									gui.text(text: 'Click Count ${state.click_count}'),
								]
								on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
									mut state := w.state[AppState]()
									state.click_count += 1
								}
							),
							gui.text(
								text: 'progress bar'
							),
							gui.progress_bar(
								percent:    (app.click_count * 4) / f32(100)
								sizing:     gui.fill_fit
								min_height: 20
							),
							gui.row(
								v_align: .middle
								padding: gui.padding_none
								content: [
									gui.text(
										text: 'label'
									),
									gui.input(
										id_focus:     2
										width:        120
										sizing:       gui.fixed_fit
										text:         state.other_input
										placeholder:  'Type here...'
										mode:         .single_line
										border_width: 2

										on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
											mut state := w.state[AppState]()
											state.other_input = s
										}
									),
								]
							),
						]
					),
					gui.rectangle(
						width:     25
						height:    25
						fill:      true
						sizing:    gui.fill_fill
						color:     gui.dark_green
					),
				]
			),
			gui.column(
				color:   gui.theme().color_panel
				fill:    true
				sizing:  gui.fill_fill
				spacing: gui.spacing_large
				content: [
					gui.input(
						id_focus:     3
						width:        250
						text:         state.name
						mode:         .multiline
						sizing:       gui.fixed_fit
						border_width: 2

						on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
							mut state := w.state[AppState]()
							state.name = s
						}
					),
					gui.column(
						color:    gui.theme().text_style.color
						fill:     false
						sizing:   gui.fill_fit
						title:    '  mode = .wrap  '
						title_bg: gui.theme().color_panel
						content:  [
							gui.text(
								id_focus: 6
								text:     state.name
								mode:     .wrap
							),
						]
					),
					gui.column(
						color:    gui.theme().text_style.color
						fill:     false
						sizing:   gui.fill_fit
						title:    '  mode = .wrap_keep_spaces  '
						title_bg: gui.theme().color_panel
						content:  [
							gui.text(
								id_focus: 7
								text:     state.name
								mode:     .wrap_keep_spaces
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
