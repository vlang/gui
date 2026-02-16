import gui

// SVG Viewer
// =============================
// Displays embedded SVG samples in a sidebar + content panel layout.
// Demonstrates gui.svg() with $embed_file SVG assets.

struct SvgEntry {
	name     string
	svg_data string
}

fn svg_entries() []SvgEntry {
	return [
		SvgEntry{'Drop Shadow Filter', $embed_file('../assets/svgs/drop_shadow_filter.svg').to_string()},
		SvgEntry{'Gradient Logo', $embed_file('../assets/svgs/gradient_logo.svg').to_string()},
		SvgEntry{'Loading Spinner', $embed_file('../assets/svgs/loading_spinner.svg').to_string()},
		SvgEntry{'Text with Fonts', $embed_file('../assets/svgs/text_with_fonts.svg').to_string()},
		SvgEntry{'Transparent Icon', $embed_file('../assets/svgs/transparent_icon.svg').to_string()},
		SvgEntry{'Sample Transparent', $embed_file('../assets/svgs/sample_transparent.svg').to_string()},
		SvgEntry{'Sample with BG', $embed_file('../assets/svgs/sample_with_bg.svg').to_string()},
	]
}

@[heap]
struct SvgViewerApp {
pub mut:
	selected int
}

fn main() {
	mut window := gui.window(
		state:   &SvgViewerApp{}
		width:   900
		height:  700
		title:   'SVG Viewer'
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[SvgViewerApp]()

	return gui.row(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		content: [
			nav_panel(app.selected),
			content_panel(app.selected),
		]
	)
}

fn nav_panel(selected int) gui.View {
	mut nav_items := []gui.View{}
	for i, entry in svg_entries() {
		color := if i == selected {
			gui.theme().color_active
		} else {
			gui.color_transparent
		}
		idx := i
		nav_items << gui.row(
			color:    color
			padding:  gui.padding_two_five
			sizing:   gui.fill_fit
			on_click: fn [idx] (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
				mut app := w.state[SvgViewerApp]()
				app.selected = idx
			}
			content:  [
				gui.text(text: entry.name),
			]
			on_hover: fn (mut layout gui.Layout, mut _ gui.Event, mut w gui.Window) {
				w.set_mouse_cursor_pointing_hand()
				layout.shape.color = gui.theme().color_hover
			}
		)
	}

	return gui.column(
		id:      'nav'
		color:   gui.theme().color_panel
		sizing:  gui.fit_fill
		content: nav_items
	)
}

fn content_panel(selected int) gui.View {
	entry := svg_entries()[selected]
	return gui.column(
		id:      'content'
		color:   gui.theme().color_panel
		sizing:  gui.fill_fill
		h_align: .center
		v_align: .middle
		content: [
			gui.svg(svg_data: entry.svg_data),
		]
	)
}
