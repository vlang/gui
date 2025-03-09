# GUI

A UI frame work for the V language based on the rendering algorithm of Clay.

It's early days so very little is working. Try it and send me feedback.

## Features

- Pure V (so far...)
- Immediate mode rendering
- Thread safe view updates
- Declarative layout syntax
- Dynamic layout

## Example
```v
module main

import gui
import gx

fn main() {
	mut window := gui.window(
		title:      'test layout'
		width:      1000
		height:     400
		bg_color:   gx.rgb(0x30, 0x30, 0x30)
		on_init:    fn (mut w gui.Window) {
			w.update_view(main_view(w))
		}
		on_resized: fn (mut w gui.Window) {
			w.update_view(main_view(w))
		}
	)
	window.run()
}

fn main_view(w &gui.Window) gui.UI_Tree {
	width, height := w.window_size()
	return gui.row(
		width:    width
		height:   height
		sizing:   gui.Sizing{.fixed, .fixed}
		spacing:  10
		padding:  gui.Padding{10, 10, 10, 10}
		fill:     true
		color:    gx.dark_blue
		children: [
			gui.rectangle(
				width:  75
				height: 50
				fill:   true
				radius: 5
				color:  gx.purple
			),
			gui.row(
				spacing:  10
				padding:  gui.Padding{10, 10, 10, 10}
				radius:   5
				color:    gx.orange
				children: [
					gui.column(
						width:    25
						height:   25
						spacing:  20
						padding:  gui.Padding{10, 10, 10, 10}
						fill:     true
						radius:   5
						color:    gx.black
						children: [
							gui.label(text: 'Hello world!'),
							gui.label(text: 'This is text'),
							gui.label(text: 'Embedded in a column'),
						]
					),
					gui.rectangle(
						width:  25
						height: 25
						sizing: gui.Sizing{.fixed, .dynamic}
						fill:   true
						radius: 5
						color:  gx.violet
					),
				]
			),
			gui.rectangle(
				width:  75
				height: 50
				sizing: gui.Sizing{.dynamic, .dynamic}
				fill:   true
				radius: 5
				color:  gx.red
			),
			gui.rectangle(
				width:  75
				height: 50
				fill:   true
				radius: 5
				color:  gx.orange
			),
		]
	)
}
````
![screen shot](gui.png)