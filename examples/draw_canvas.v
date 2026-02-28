import gui

const data = [f32(2), 5, 3, 8, 6, 4, 7, 9, 5, 10, 8, 6, 11, 7]

fn main() {
	mut window := gui.window(
		title:   'Draw Canvas — Line Chart'
		width:   640
		height:  480
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		padding: gui.theme().padding_large
		spacing: 16
		content: [
			gui.text(text: 'Line Chart', text_style: gui.theme().b1),
			gui.draw_canvas(
				id:      'chart'
				version: 1
				width:   560
				height:  360
				color:   gui.Color{30, 30, 40, 255}
				radius:  8
				padding: gui.Padding{30, 40, 40, 50}
				on_draw: fn (mut dc gui.DrawContext) {
					draw_chart(mut dc)
				}
			),
		]
	)
}

fn draw_chart(mut dc gui.DrawContext) {
	cw := dc.width
	ch := dc.height

	// Grid lines.
	grid_color := gui.Color{80, 80, 100, 255}
	rows := 5
	for i in 0 .. rows + 1 {
		y := ch * f32(i) / f32(rows)
		dc.line(0, y, cw, y, grid_color, 1)
	}
	cols := data.len - 1
	for i in 0 .. cols + 1 {
		x := cw * f32(i) / f32(cols)
		dc.line(x, 0, x, ch, grid_color, 1)
	}

	// Data range.
	mut mn := data[0]
	mut mx := data[0]
	for v in data {
		if v < mn {
			mn = v
		}
		if v > mx {
			mx = v
		}
	}
	span := if mx > mn { mx - mn } else { f32(1) }

	// Build polyline points.
	mut pts := []f32{cap: data.len * 2}
	for i, v in data {
		x := cw * f32(i) / f32(data.len - 1)
		y := ch - ch * (v - mn) / span
		pts << x
		pts << y
	}

	// Filled area under curve.
	mut area := []f32{cap: pts.len + 4}
	area << pts
	area << cw
	area << ch
	area << f32(0)
	area << ch
	dc.filled_polygon(area, gui.Color{70, 130, 220, 60})

	// Line.
	dc.polyline(pts, gui.Color{70, 130, 220, 255}, 2.5, .round, .round)

	// Dot markers.
	for i := 0; i < pts.len; i += 2 {
		dc.filled_circle(pts[i], pts[i + 1], 4, gui.Color{220, 220, 255, 255})
	}
}
