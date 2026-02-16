import gui
import os

const print_source_width = f32(520.0)
const print_source_height = f32(1120.0)
const print_output_name = 'v_gui_printing_demo.pdf'

const svg_flow = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 90"><rect x="6" y="6" width="188" height="78" rx="14" fill="#0f1a2d"/><path d="M24 58 L62 24 L100 58 L138 26 L176 58" fill="none" stroke="#7ce8ff" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/><circle cx="62" cy="24" r="7" fill="#7ce8ff"/><circle cx="100" cy="58" r="7" fill="#78f0a4"/><circle cx="138" cy="26" r="7" fill="#ffc86b"/></svg>'
const svg_clip = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 180 90"><defs><clipPath id="printClip"><circle cx="46" cy="45" r="28"/></clipPath></defs><rect x="4" y="4" width="172" height="82" rx="10" fill="#1a1e2f"/><rect x="12" y="14" width="70" height="62" fill="#3f80ff" clip-path="url(#printClip)"/><circle cx="118" cy="45" r="23" fill="#ff8c66"/><rect x="138" y="24" width="24" height="42" rx="4" fill="#7fd1ff"/></svg>'
const svg_grid = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 180 90"><rect x="4" y="4" width="172" height="82" rx="10" fill="#18243b"/><rect x="18" y="18" width="32" height="22" rx="4" fill="#6fb3ff"/><rect x="58" y="18" width="32" height="22" rx="4" fill="#9ce27a"/><rect x="98" y="18" width="32" height="22" rx="4" fill="#ffb363"/><rect x="138" y="18" width="24" height="22" rx="4" fill="#ff7e9b"/><rect x="18" y="50" width="60" height="22" rx="4" fill="#68d4c0"/><rect x="84" y="50" width="78" height="22" rx="4" fill="#7b8fff"/></svg>'

@[heap]
struct PrintingApp {
pub mut:
	last_path   string
	last_result string
	grad_header gui.Gradient
	grad_card   gui.Gradient
	grad_accent gui.Gradient
}

fn (mut app PrintingApp) init_gradients() {
	app.grad_header = gui.Gradient{
		direction: .to_right
		stops:     [
			gui.GradientStop{
				color: gui.Color{35, 87, 195, 255}
				pos:   0.0
			},
			gui.GradientStop{
				color: gui.Color{66, 196, 208, 255}
				pos:   1.0
			},
		]
	}
	app.grad_card = gui.Gradient{
		direction: .to_bottom_right
		stops:     [
			gui.GradientStop{
				color: gui.Color{122, 99, 255, 255}
				pos:   0.0
			},
			gui.GradientStop{
				color: gui.Color{239, 107, 174, 255}
				pos:   1.0
			},
		]
	}
	app.grad_accent = gui.Gradient{
		direction: .to_right
		stops:     [
			gui.GradientStop{
				color: gui.Color{71, 169, 98, 255}
				pos:   0.0
			},
			gui.GradientStop{
				color: gui.Color{164, 215, 115, 255}
				pos:   1.0
			},
		]
	}
}

fn demo_print_job() gui.PrintJob {
	return demo_print_job_with_output('')
}

fn demo_print_job_with_output(output_path string) gui.PrintJob {
	return gui.PrintJob{
		output_path:   output_path
		title:         'Printing Demo Report'
		job_name:      'v-gui Printing Demo'
		paper:         .a4
		orientation:   .portrait
		margins:       gui.PrintMargins{
			top:    36
			right:  36
			bottom: 36
			left:   36
		}
		source:        gui.PrintJobSource{
			kind: .current_view
		}
		paginate:      true
		scale_mode:    .actual_size
		header:        gui.PrintHeaderFooterCfg{
			enabled: true
			left:    '{title}'
			right:   '{page}/{pages}'
		}
		footer:        gui.PrintHeaderFooterCfg{
			enabled: true
			left:    '{date}'
			right:   'v-gui printing'
		}
		source_width:  print_source_width
		source_height: print_source_height
	}
}

fn main() {
	mut app := &PrintingApp{}
	app.init_gradients()
	mut window := gui.window(
		state:   app
		width:   700
		height:  int(print_source_height)
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
	last_result := if app.last_result.len > 0 { app.last_result } else { 'No print action yet.' }
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
			gui.text(
				text:       'Exports exactly two A4 pages with pagination, header/footer tokens, gradients, and SVG content.'
				mode:       .wrap
				text_style: gui.theme().n5
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
			gui.text(text: 'Last result: ${last_result}', mode: .wrap),
			scrolling_notes(),
			print_preview(app),
		]
	)
}

fn scrolling_notes() gui.View {
	return gui.column(
		height:          96
		color:           gui.theme().color_panel
		color_border:    gui.theme().color_border
		size_border:     1
		padding:         gui.padding_small
		spacing:         6
		id_scroll:       41
		scrollbar_cfg_y: &gui.ScrollbarCfg{
			overflow: .auto
		}
		content:         [
			gui.text(text: 'Scrollable Notes', text_style: gui.theme().b5),
			gui.text(text: 'Line 1: Mouse wheel scroll is enabled in this panel.', mode: .wrap),
			gui.text(text: 'Line 2: PDF export still uses the fixed print profile.', mode: .wrap),
			gui.text(text: 'Line 3: Header and footer tokens expand during export.', mode: .wrap),
			gui.text(text: 'Line 4: SVG rows and gradients are preserved in output.', mode: .wrap),
			gui.text(
				text: 'Line 5: Buttons above continue to control export and print.'
				mode: .wrap
			),
			gui.text(text: 'Line 6: Keep scrolling to verify panel overflow behavior.', mode: .wrap),
		]
	)
}

fn export_button() gui.View {
	return gui.button(
		content:  [gui.text(text: 'Export PDF')]
		on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			path := os.join_path(os.temp_dir(), print_output_name)
			result := w.export_print_job(demo_print_job_with_output(path))
			mut app := w.state[PrintingApp]()
			if result.is_ok() {
				app.last_path = result.path
				app.last_result = 'Exported: ${result.path}'
			} else {
				app.last_result = 'Export failed: ${result.error_code}: ${result.error_message}'
			}
		}
	)
}

fn print_current_button() gui.View {
	return gui.button(
		content:  [gui.text(text: 'Print Current View')]
		on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			w.state[PrintingApp]().last_result = 'Opening print dialog...'
			w.queue_command(fn (mut w gui.Window) {
				result := w.run_print_job(demo_print_job())
				mut app := w.state[PrintingApp]()
				match result.status {
					.ok {
						app.last_path = result.pdf_path
						app.last_result = 'Printed: ${result.pdf_path}'
					}
					.cancel {
						app.last_result = 'Print canceled.'
					}
					.error {
						app.last_result = 'Print failed: ${result.error_code}: ${result.error_message}'
					}
				}
			})
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
			w.state[PrintingApp]().last_result = 'Opening print dialog...'
			w.queue_command(fn [path] (mut w gui.Window) {
				result := w.run_print_job(gui.PrintJob{
					title:  'Print Existing PDF'
					source: gui.PrintJobSource{
						kind:     .pdf_path
						pdf_path: path
					}
				})
				mut app := w.state[PrintingApp]()
				match result.status {
					.ok {
						app.last_result = 'Printed: ${result.pdf_path}'
					}
					.cancel {
						app.last_result = 'Print canceled.'
					}
					.error {
						app.last_result = 'Print failed: ${result.error_code}: ${result.error_message}'
					}
				}
			})
		}
	)
}

fn print_preview(app &PrintingApp) gui.View {
	return gui.column(
		width:        484
		height:       930
		color:        gui.theme().color_panel
		color_border: gui.theme().color_border
		size_border:  1
		padding:      gui.padding_large
		spacing:      10
		content:      [
			gui.text(
				text:       'Page 1: vector preview, status copy, and gradient sections'
				text_style: gui.theme().b5
			),
			gui.column(
				height:   110
				radius:   12
				padding:  gui.Padding{14, 14, 14, 14}
				gradient: &app.grad_header
				spacing:  6
				content:  [
					gui.text(
						text:       'Operations Summary'
						text_style: gui.TextStyle{
							...gui.theme().b4
							color: gui.white
						}
					),
					gui.text(
						text:       'Text, gradients, and SVG renderers are captured from the current view and streamed to PDF.'
						mode:       .wrap
						text_style: gui.TextStyle{
							...gui.theme().n5
							color: gui.white
						}
					),
				]
			),
			gui.text(
				text:       'Cards below map to multi-page content. PDF export uses paginate=true and actual_size for deterministic paging.'
				mode:       .wrap
				text_style: gui.theme().n5
			),
			gui.row(
				spacing: 10
				content: [
					gui.column(
						width:    220
						height:   110
						radius:   10
						padding:  gui.Padding{10, 10, 10, 10}
						gradient: &app.grad_card
						spacing:  8
						content:  [
							gui.text(
								text:       'Card A'
								text_style: gui.TextStyle{
									...gui.theme().b5
									color: gui.white
								}
							),
							gui.text(
								text:       'Gradient fill + wrapped text.'
								mode:       .wrap
								text_style: gui.TextStyle{
									...gui.theme().n5
									color: gui.white
								}
							),
						]
					),
					gui.column(
						width:    220
						height:   110
						radius:   10
						padding:  gui.Padding{10, 10, 10, 10}
						gradient: &app.grad_accent
						spacing:  8
						content:  [
							gui.text(
								text:       'Card B'
								text_style: gui.TextStyle{
									...gui.theme().b5
									color: gui.Color{24, 24, 24, 255}
								}
							),
							gui.text(
								text:       'Used to verify gradient paths in PDF.'
								mode:       .wrap
								text_style: gui.TextStyle{
									...gui.theme().n5
									color: gui.Color{24, 24, 24, 255}
								}
							),
						]
					),
				]
			),
			gui.row(
				spacing: 10
				content: [
					gui.svg(
						svg_data: svg_flow
						width:    144
						height:   74
					),
					gui.svg(
						svg_data: svg_clip
						width:    144
						height:   74
					),
					gui.svg(
						svg_data: svg_grid
						width:    144
						height:   74
					),
				]
			),
			gui.text(
				text:       'Page 2 starts after the spacer. Content below intentionally repeats all major primitives.'
				mode:       .wrap
				text_style: gui.theme().n5
			),
			gui.rectangle(
				width:  1
				height: 220
				color:  gui.color_transparent
			),
			gui.text(
				text:       'Page 2: additional gradients and SVG samples'
				text_style: gui.theme().b5
			),
			gui.column(
				height:   120
				radius:   12
				padding:  gui.Padding{14, 14, 14, 14}
				gradient: &app.grad_header
				spacing:  6
				content:  [
					gui.text(
						text:       'Follow-up Section'
						text_style: gui.TextStyle{
							...gui.theme().b4
							color: gui.white
						}
					),
					gui.text(
						text:       'Footer tokens print date/time and static labels while this section validates second-page rendering.'
						mode:       .wrap
						text_style: gui.TextStyle{
							...gui.theme().n5
							color: gui.white
						}
					),
				]
			),
			gui.row(
				spacing: 10
				content: [
					gui.svg(
						svg_data: svg_grid
						width:    150
						height:   80
					),
					gui.column(
						width:   286
						spacing: 8
						content: [
							gui.text(
								text:       'Second-page body text is wrapped and paired with another gradient card.'
								mode:       .wrap
								text_style: gui.theme().n5
							),
							gui.column(
								height:   86
								radius:   10
								padding:  gui.Padding{10, 10, 10, 10}
								gradient: &app.grad_card
								spacing:  6
								content:  [
									gui.text(
										text:       'Card C'
										text_style: gui.TextStyle{
											...gui.theme().b5
											color: gui.white
										}
									),
									gui.text(
										text:       'Ensures gradients appear on page 2.'
										mode:       .wrap
										text_style: gui.TextStyle{
											...gui.theme().n5
											color: gui.white
										}
									),
								]
							),
						]
					),
				]
			),
			gui.text(
				text:       'Print Last PDF remains enabled after export and reuses the generated file path.'
				mode:       .wrap
				text_style: gui.theme().n5
			),
		]
	)
}
