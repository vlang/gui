import gui

// Badge
// =============================
// Demonstrates badge variants, max cap, and dot mode.

@[heap]
struct BadgeApp {
}

fn main() {
	mut window := gui.window(
		state:   &BadgeApp{}
		title:   'Badge'
		width:   400
		height:  300
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
		spacing: gui.theme().spacing_medium
		padding: gui.theme().padding_medium
		content: [
			gui.text(text: 'Badge', text_style: gui.theme().b2),
			gui.text(text: 'Variants', text_style: gui.theme().b4),
			gui.row(
				color:       gui.color_transparent
				size_border: 0
				spacing:     gui.theme().spacing_small
				v_align:     .middle
				content:     [
					gui.badge(label: '5'),
					gui.badge(label: '3', variant: .info),
					gui.badge(label: '12', variant: .success),
					gui.badge(label: '7', variant: .warning),
					gui.badge(label: '99', variant: .error),
				]
			),
			gui.text(text: 'Max cap', text_style: gui.theme().b4),
			gui.row(
				color:       gui.color_transparent
				size_border: 0
				spacing:     gui.theme().spacing_small
				v_align:     .middle
				content:     [
					gui.badge(label: '5', max: 99),
					gui.badge(label: '150', max: 99, variant: .error),
					gui.badge(label: '1000', max: 999, variant: .info),
				]
			),
			gui.text(text: 'Dot mode', text_style: gui.theme().b4),
			gui.row(
				color:       gui.color_transparent
				size_border: 0
				spacing:     gui.theme().spacing_small
				v_align:     .middle
				content:     [
					gui.badge(dot: true),
					gui.badge(dot: true, variant: .info),
					gui.badge(dot: true, variant: .success),
					gui.badge(dot: true, variant: .warning),
					gui.badge(dot: true, variant: .error),
				]
			),
		]
	)
}
