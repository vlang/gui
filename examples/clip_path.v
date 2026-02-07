import gui

const test_circle_clip = '<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"><defs><clipPath id="circleClip"><circle cx="50" cy="50" r="40"/></clipPath></defs><rect width="100" height="100" fill="blue" clip-path="url(#circleClip)"/><rect x="10" y="10" width="80" height="80" fill="red" clip-path="url(#circleClip)"/></svg>'

const test_path_clip_group = '<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"><defs><clipPath id="starClip"><path d="M50 5 L61 40 L98 40 L68 62 L79 97 L50 75 L21 97 L32 62 L2 40 L39 40 Z"/></clipPath></defs><g clip-path="url(#starClip)"><rect width="100" height="50" fill="green"/><rect y="50" width="100" height="50" fill="orange"/></g></svg>'

const test_no_clip = '<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"><rect width="100" height="100" fill="#ccc"/><circle cx="50" cy="50" r="40" fill="purple"/></svg>'

fn main() {
	mut window := gui.window(
		title:   'clipPath Test'
		width:   600
		height:  250
		on_init: fn (mut w gui.Window) {
			w.update_view(fn (window &gui.Window) gui.View {
				return gui.row(
					padding: gui.Padding{10, 10, 10, 10}
					spacing: 20
					content: [
						gui.column(
							spacing: 5
							content: [
								gui.text(text: 'Circle clip'),
								gui.svg(
									svg_data: test_circle_clip
									width:    150
									height:   150
								),
							]
						),
						gui.column(
							spacing: 5
							content: [
								gui.text(text: 'Star clip group'),
								gui.svg(
									svg_data: test_path_clip_group
									width:    150
									height:   150
								),
							]
						),
						gui.column(
							spacing: 5
							content: [
								gui.text(text: 'No clip (control)'),
								gui.svg(
									svg_data: test_no_clip
									width:    150
									height:   150
								),
							]
						),
					]
				)
			})
		}
	)
	window.run()
}
