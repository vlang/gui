import gui

// Icon Font Demo
// =============================

@[heap]
struct IconFontApp {
}

fn main() {
	mut window := gui.window(
		title:   'Icon Font'
		state:   &IconFontApp{}
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
	// app := window.state[IconFontApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		content: [
			icon_catalog(),
		]
	)
}

fn icon_catalog() gui.View {
	icon_text_style := gui.TextStyle{
		...gui.theme().text_style
		family: gui.icon_font_file
		size:   24
	}

	chunks := chunk_map(gui.icons_map, 5)
	mut all_icons := []gui.View{}

	for chunk in chunks {
		mut icons := []gui.View{}
		for key, val in chunk {
			icons << gui.column(
				min_width: 150
				padding:   gui.padding_none
				h_align:   .center
				content:   [
					gui.text(text: val, text_style: icon_text_style),
					gui.text(text: key),
				]
			)
		}
		all_icons << gui.row(
			spacing: 0
			padding: gui.padding_none
			content: icons
		)
	}

	return gui.column(
		id_scroll: 1
		spacing:   gui.spacing_large
		sizing:    gui.fill_fill
		content:   all_icons
	)
}

fn chunk_map[K, V](input map[K]V, chunk_size int) []map[K]V {
	mut chunks := []map[K]V{}
	mut current_chunk := map[K]V{}
	mut count := 0

	for key, value in input {
		current_chunk[key] = value
		count++
		if count == chunk_size {
			chunks << current_chunk
			current_chunk = map[K]V{}
			count = 0
		}
	}
	// Add any remaining items as the last chunk
	if current_chunk.len > 0 {
		chunks << current_chunk
	}
	return chunks
}
