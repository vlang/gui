import gui

// Gallery
// =============================
// WIP

@[heap]
struct GalleryApp {
pub mut:
	button_clicks   int
	input_text      string
	input_multiline string = 'Now is the time for all good men to come to the aid of their country'
}

fn main() {
	mut window := gui.window(
		state:   &GalleryApp{}
		width:   800
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
		id_scroll: 1
		fill:      true
		color:     gui.theme().color_1
		sizing:    gui.fill_fill
		content:   [
			buttons(w),
			inputs(w),
			text_sizes_weights(w),
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
	app := w.state[GalleryApp]()
	return gui.column(
		padding: gui.padding_none
		sizing:  gui.fill_fit
		content: [
			view_title('Buttons'),
			gui.row(
				sizing:  gui.fill_fit
				padding: gui.padding_none
				v_align: .bottom
				content: [
					gui.button(
						id_focus:       100
						padding_border: gui.padding_none
						content:        [gui.text(text: 'No Border')]
						on_click:       button_click
					),
					gui.button(
						id_focus:       101
						padding_border: gui.padding_one
						content:        [gui.text(text: 'Thin Border')]
						on_click:       button_click
					),
					gui.button(
						id_focus:       102
						padding_border: gui.padding_two
						content:        [gui.text(text: 'Thicker Border')]
						on_click:       button_click
					),
					gui.button(
						id_focus:       103
						padding_border: gui.padding_three
						fill_border:    false
						content:        [gui.text(text: 'Detached Border')]
						on_click:       button_click
					),
					gui.button(
						id_focus:       104
						padding_border: gui.padding_two
						on_click:       fn (_ &gui.ButtonCfg, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[GalleryApp]()
							app.button_clicks += 1
						}
						content:        [
							gui.column(
								spacing: gui.spacing_small
								padding: gui.padding_none
								h_align: .center
								content: [
									gui.text(
										text:       'Custom Content'
										text_style: gui.theme().n6
									),
									gui.progress_bar(
										color:      gui.blue
										color_bar:  gui.dark_green
										percent:    (app.button_clicks % 25) / f32(25)
										sizing:     gui.fill_fit
										text_style: gui.theme().m4
										height:     gui.theme().n3.size
									),
								]
							),
						]
					),
				]
			),
		]
	)
}

fn button_click(_ &gui.ButtonCfg, mut e gui.Event, mut w gui.Window) {
	e.is_handled = true
}

fn inputs(w &gui.Window) gui.View {
	app := w.state[GalleryApp]()
	return gui.column(
		padding: gui.padding_none
		sizing:  gui.fill_fit
		content: [
			view_title('Inputs'),
			gui.row(
				sizing:  gui.fill_fit
				padding: gui.padding_none
				content: [
					gui.input(
						id_focus:        200
						width:           150
						sizing:          gui.fixed_fit
						text:            app.input_text
						padding_border:  gui.padding_none
						color:           gui_theme.color_0
						placeholder:     'Plain...'
						mode:            .single_line
						on_text_changed: text_changed
					),
					gui.input(
						id_focus:        201
						width:           130
						sizing:          gui.fixed_fit
						text:            app.input_text
						padding_border:  gui.padding_one
						placeholder:     'Thin Border...'
						mode:            .single_line
						on_text_changed: text_changed
					),
					gui.input(
						id_focus:        202
						width:           130
						sizing:          gui.fixed_fit
						text:            app.input_text
						padding_border:  gui.padding_two
						placeholder:     'Thicker Border...'
						mode:            .single_line
						on_text_changed: text_changed
					),
					gui.input(
						id_focus:        203
						width:           130
						sizing:          gui.fixed_fit
						text:            app.input_text
						padding_border:  gui.padding_one
						placeholder:     'Password...'
						is_password:     true
						mode:            .single_line
						on_text_changed: text_changed
					),
				]
			),
			gui.row(
				sizing:  gui.fill_fit
				padding: gui.padding_none
				v_align: .middle
				content: [
					gui.text(text: 'Multiline Text Input:'),
					gui.input(
						id_focus:        204
						width:           300
						sizing:          gui.fixed_fit
						text:            app.input_multiline
						padding_border:  gui.padding_one
						placeholder:     'Multline...'
						mode:            .multiline
						on_text_changed: fn (_ &gui.InputCfg, s string, mut w gui.Window) {
							mut app := w.state[GalleryApp]()
							app.input_multiline = s
						}
					),
				]
			),
		]
	)
}

fn text_changed(_ &gui.InputCfg, s string, mut w gui.Window) {
	mut app := w.state[GalleryApp]()
	app.input_text = s
}

fn text_sizes_weights(w &gui.Window) gui.View {
	return gui.column(
		padding: gui.padding_none
		sizing:  gui.fill_fit
		content: [
			view_title('Text Sizes & Weights'),
			gui.row(
				sizing:  gui.fill_fit
				padding: gui.padding_none
				content: [
					gui.text(text: 'Theme().n1', text_style: gui.theme().n1),
					gui.text(text: 'Theme().n2', text_style: gui.theme().n2),
					gui.text(text: 'Theme().n3', text_style: gui.theme().n3),
					gui.text(text: 'Theme().n4', text_style: gui.theme().n4),
					gui.text(text: 'Theme().n5', text_style: gui.theme().n5),
					gui.text(text: 'Theme().n6', text_style: gui.theme().n6),
				]
			),
			gui.row(
				sizing:  gui.fill_fit
				padding: gui.padding_none
				content: [
					gui.text(text: 'Theme().b1', text_style: gui.theme().b1),
					gui.text(text: 'Theme().b2', text_style: gui.theme().b2),
					gui.text(text: 'Theme().b3', text_style: gui.theme().b3),
					gui.text(text: 'Theme().b4', text_style: gui.theme().b4),
					gui.text(text: 'Theme().b5', text_style: gui.theme().b5),
					gui.text(text: 'Theme().b6', text_style: gui.theme().b6),
				]
			),
			gui.row(
				sizing:  gui.fill_fit
				padding: gui.padding_none
				content: [
					gui.text(text: 'Theme().i1', text_style: gui.theme().i1),
					gui.text(text: 'Theme().i2', text_style: gui.theme().i2),
					gui.text(text: 'Theme().i3', text_style: gui.theme().i3),
					gui.text(text: 'Theme().i4', text_style: gui.theme().i4),
					gui.text(text: 'Theme().i5', text_style: gui.theme().i5),
					gui.text(text: 'Theme().i6', text_style: gui.theme().i6),
				]
			),
			gui.row(
				sizing:  gui.fill_fit
				padding: gui.padding_none
				content: [
					gui.text(text: 'Theme().m1', text_style: gui.theme().m1),
					gui.text(text: 'Theme().m2', text_style: gui.theme().m2),
					gui.text(text: 'Theme().m3', text_style: gui.theme().m3),
					gui.text(text: 'Theme().m4', text_style: gui.theme().m4),
					gui.text(text: 'Theme().m5', text_style: gui.theme().m5),
					gui.text(text: 'Theme().m6', text_style: gui.theme().m6),
				]
			),
		]
	)
}
