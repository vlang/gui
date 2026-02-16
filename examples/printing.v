import gui
import os

@[heap]
struct PrintingApp {
pub mut:
	last_path string
}

fn main() {
	mut window := gui.window(
		state:   &PrintingApp{}
		width:   700
		height:  420
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[PrintingApp]()
	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		padding: gui.padding_large
		spacing: 16
		content: [
			gui.text(
				text:       'Printing Demo'
				text_style: gui.theme().b1
			),
			gui.row(
				spacing: 12
				content: [
					export_button(),
					print_current_button(),
					print_file_button(app.last_path),
				]
			),
			gui.text(text: 'Last exported path: ${app.last_path}'),
			print_preview(),
		]
	)
}

fn export_button() gui.View {
	return gui.button(
		content:  [gui.text(text: 'Export PDF')]
		on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			path := os.join_path(os.temp_dir(), 'v_gui_printing_demo.pdf')
			result := w.export_print_job(gui.PrintJob{
				output_path: path
				source:      gui.PrintJobSource{
					kind: .current_view
				}
			})
			if result.is_ok() {
				w.state[PrintingApp]().last_path = result.path
				w.dialog(title: 'Export PDF', body: result.path)
			} else {
				w.dialog(title: 'Export PDF', body: '${result.error_code}: ${result.error_message}')
			}
		}
	)
}

fn print_current_button() gui.View {
	return gui.button(
		content:  [gui.text(text: 'Print Current View')]
		on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			result := w.run_print_job(gui.PrintJob{
				title:  'Print Current View'
				source: gui.PrintJobSource{
					kind: .current_view
				}
			})
			match result.status {
				.ok {
					w.state[PrintingApp]().last_path = result.pdf_path
					w.dialog(title: 'Print', body: 'Printed ${result.pdf_path}')
				}
				.cancel {
					w.dialog(title: 'Print', body: 'Canceled.')
				}
				.error {
					w.dialog(title: 'Print', body: '${result.error_code}: ${result.error_message}')
				}
			}
		}
	)
}

fn print_file_button(last_path string) gui.View {
	return gui.button(
		content:  [gui.text(text: 'Print Last PDF')]
		disabled: last_path.len == 0
		on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			path := w.state[PrintingApp]().last_path
			if path.len == 0 {
				return
			}
			result := w.run_print_job(gui.PrintJob{
				title:  'Print Existing PDF'
				source: gui.PrintJobSource{
					kind:     .pdf_path
					pdf_path: path
				}
			})
			match result.status {
				.ok {
					w.dialog(title: 'Print', body: 'Printed ${result.pdf_path}')
				}
				.cancel {
					w.dialog(title: 'Print', body: 'Canceled.')
				}
				.error {
					w.dialog(title: 'Print', body: '${result.error_code}: ${result.error_message}')
				}
			}
		}
	)
}

fn print_preview() gui.View {
	return gui.column(
		color:        gui.theme().color_panel
		color_border: gui.theme().color_border
		size_border:  1
		padding:      gui.padding_large
		spacing:      8
		content:      [
			gui.text(text: 'Sample content that gets exported/printed.'),
			gui.text(text: 'Rectangles, lines, text, and SVG triangles map to PDF vector ops.'),
			gui.row(
				spacing: 8
				content: [
					gui.rectangle(
						width:  80
						height: 40
						color:  gui.Color{
							r: 52
							g: 126
							b: 255
							a: 255
						}
					),
					gui.rectangle(
						width:        80
						height:       40
						color:        gui.color_transparent
						color_border: gui.theme().color_active
						size_border:  2
					),
				]
			),
		]
	)
}
