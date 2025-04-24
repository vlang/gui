import gui

// Floating Layouts
// =============================
// Many UI designs need to draw content over other content.
// Menus and Alert Boxes for instance. GUI calls these
// floats. Floats can be nested for z axis stacking often
// required in drop down menus.
//
// Floats can be anchored to their parent container at six points.
// - top_left
// - top_center
// - top_right
// - middle_left
// - middle_center
// - middle_right
// - bottom_left
// - bottom_center
// - bottom_right
//
// The float itself has similar attchement points called, "tie-offs".
//
// A boating analogy can help with picturing how this works. A boat
// cna be anchored in a harbor but the anchor line can be tied-off
// to the bow or stern.
}

@[heap]
struct App {
pub mut:
	light bool
}

fn main() {
	mut window := gui.window(
		state:   &App{}
		width:   500
		height:  500
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
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
			// Don't have a menu view yet but one can be easily be
			// composed using only gui primitives and float layouts.
			gui.row(
				color:   gui.theme().color_2
				fill:    true
				sizing:  gui.fill_fit
				v_align: .middle
				content: [
					gui.text(text: 'File'),
					faux_edit_menu(app),
					gui.rectangle(sizing: gui.fill_fit),
					theme_button(app),
				]
			),
			gui.row(
				padding: gui.padding_none
				sizing:  gui.fill_fill
				content: [
					gui.column(
						color:     gui.theme().color_2
						fill:      true
						sizing:    gui.fill_fill
						min_width: 100
						max_width: 150
					),
					gui.column(
						color:     gui.theme().color_2
						fill:      true
						sizing:    gui.fill_fill
						min_width: 100
					),
				]
			),
			gui.column(
				float:         true
				float_anchor:  .middle_center
				float_tie_off: .middle_center
				h_align:       .center
				color:         gui.theme().color_5
				fill:          true
				content:       [
					gui.text(text: 'Floating column with content', text_style: gui.theme().b2),
					gui.button(content: [gui.text(text: 'OK')]),
				]
			),
		]
	)
}

fn faux_edit_menu(app &App) gui.View {
	return gui.column(
		spacing: 0
		padding: gui.padding_none
		content: [
			gui.text(text: 'Edit'),
			gui.column(
				float:        true
				float_anchor: .bottom_left
				min_width:    75
				max_width:    100
				color:        gui.Color{
					...gui.theme().color_4
					a: 210
				}
				fill:         true
				content:      [
					gui.text(text: 'Cut'),
					gui.text(text: 'Copy'),
					gui.row(
						sizing:  gui.fill_fit
						padding: gui.padding_none
						content: [
							gui.text(text: 'Paste >'),
							gui.column(
								float:          true
								float_anchor:   .middle_right
								float_offset_x: 5
								min_width:      75
								max_width:      100
								fill:           true
								color:          gui.Color{
									...gui.theme().color_4
									a: 210
								}
								content:        [
									gui.text(text: 'Clean'),
									gui.text(text: 'Selection'),
								]
							),
						]
					),
				]
			),
		]
	)
}

fn theme_button(app &App) gui.View {
	return gui.button(
		id_focus: 3
		padding:  gui.padding_small
		content:  [
			gui.text(
				text: if app.light { '●' } else { '○' }
			),
		]
		on_click: fn (_ &gui.ButtonCfg, mut _ gui.Event, mut w gui.Window) {
			mut app := w.state[App]()
			app.light = !app.light
			theme := if app.light {
				gui.theme_light
			} else {
				gui.theme_dark
			}
			w.set_theme(theme)
		}
	)
}
