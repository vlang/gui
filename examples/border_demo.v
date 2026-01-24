module main

import gui

const win_width = 800
const win_height = 600

fn main() {
	mut window := gui.window(gui.WindowCfg{
		width:   win_width
		height:  win_height
		title:   'Border Demo'
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	})

	window.run()
}

fn main_view(window &gui.Window) gui.View {
	return gui.column(gui.ContainerCfg{
		width:   win_width
		height:  win_height
		spacing: 20
		padding: gui.pad_all(20)
		h_align: .center
		content: [
			gui.row(gui.ContainerCfg{
				spacing: 20
				content: [
					gui.rectangle(gui.RectangleCfg{
						width:        100
						height:       100
						border_width: 1.0
						fill:         false
						color:        gui.rgba(255, 0, 0, 255)
						radius:       10
					}),
					gui.rectangle(gui.RectangleCfg{
						width:        100
						height:       100
						border_width: 2.0
						fill:         false
						color:        gui.rgba(0, 255, 0, 255)
						radius:       10
					}),
					gui.rectangle(gui.RectangleCfg{
						width:        100
						height:       100
						border_width: 5.0
						fill:         false
						color:        gui.rgba(0, 0, 255, 255)
						radius:       10
					}),
					gui.rectangle(gui.RectangleCfg{
						width:        100
						height:       100
						border_width: 10.0
						fill:         false
						color:        gui.rgba(255, 255, 0, 255)
						radius:       10
					}),
				]
			}),
			gui.row(gui.ContainerCfg{
				width:        460
				height:       100
				border_width: 4.0
				fill:         false
				radius:       0
				color:        gui.rgba(255, 0, 255, 255)
				padding:      gui.padding_medium
				content:      [
					gui.text(gui.TextCfg{
						text:       'Container with 4px Border'
						text_style: gui.TextStyle{
							align: .center // TextAlignment
							color: gui.white
						}
					}),
				]
			}),
			gui.row(gui.ContainerCfg{
				width:        460
				height:       100
				border_width: 8.0
				fill:         false
				radius:       20
				color:        gui.rgba(0, 255, 255, 255)
				padding:      gui.padding_large
				content:      [
					gui.text(gui.TextCfg{
						text:       'Container with 8px Border'
						text_style: gui.TextStyle{
							align: .center // TextAlignment
							color: gui.white
						}
					}),
				]
			}),
		]
	})
}
