import gui

// Icon Font Demo
// =============================

@[heap]
struct IconFontApp {
mut:
	light_theme   bool
	selected_size string = 'x-large'
}

fn main() {
	mut window := gui.window(
		title:   'Icon Font'
		state:   &IconFontApp{}
		width:   800
		height:  600
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
			w.set_id_focus(1)
		}
	)
	window.set_theme(gui.theme_dark_no_padding)
	window.run()
}

fn main_view(mut window gui.Window) gui.View {
	w, h := window.window_size()
	// app := window.state[IconFontApp]()

	return gui.row(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		content: [
			side_panel(mut window),
			icon_catalog(mut window),
		]
	)
}

fn icon_catalog(mut w gui.Window) gui.View {
	mut app := w.state[IconFontApp]()
	icon_text_style := match app.selected_size {
		'tiny' { gui.theme().icon6 }
		'x-small' { gui.theme().icon5 }
		'small' { gui.theme().icon4 }
		'large' { gui.theme().icon2 }
		'x-large' { gui.theme().icon1 }
		else { gui.theme().icon3 }
	}

	// find the longest text
	mut longest := f32(0)
	for s in gui.icons_map.keys() {
		longest = f32_max(gui.get_text_width(s, gui.theme().n3, mut w), longest)
	}

	// Break the icons_maps into rows
	chunks := chunk_map(gui.icons_map, 4)
	mut all_icons := []gui.View{}

	// create rows of icons/text
	for chunk in chunks {
		mut icons := []gui.View{}
		for key, val in chunk {
			icons << gui.column(
				min_width: longest
				h_align:   .center
				content:   [
					gui.text(text: val, text_style: icon_text_style),
					gui.text(text: key),
				]
			)
		}
		all_icons << gui.row(
			spacing: 0
			content: icons
		)
	}

	return gui.column(
		id_focus:  1
		id_scroll: 1
		spacing:   gui.spacing_large
		sizing:    gui.fill_fill
		padding:   gui.padding_medium
		content:   all_icons
	)
}

// maybe this should be a standard library function?
fn chunk_map[K, V](input map[K]V, chunk_size int) []map[K]V {
	mut chunks := []map[K]V{}
	mut current_chunk := map[K]V{}
	mut count := 0

	for key, value in input {
		current_chunk[key] = value
		count += 1
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

fn side_panel(mut w gui.Window) gui.View {
	mut app := w.state[IconFontApp]()
	return gui.column(
		color:   gui.theme().color_2
		fill:    true
		sizing:  gui.fit_fill
		padding: gui.theme().padding_large
		content: [
			gui.radio_button_group_column(
				options:   [
					gui.radio_option('tiny', 'tiny'),
					gui.radio_option('small', 'small'),
					gui.radio_option('medium', 'medium'),
					gui.radio_option('large', 'large'),
					gui.radio_option('x-large', 'x-large'),
				]
				value:     app.selected_size
				on_select: fn [mut app] (value string, mut _ gui.Window) {
					app.selected_size = value
				}
				window:    w
			),
			gui.column(sizing: gui.fill_fill),
			toggle_theme(app),
		]
	)
}

fn toggle_theme(app &IconFontApp) gui.View {
	return gui.row(
		h_align: .end
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			gui.toggle(
				text_selected:   gui.icon_moon
				text_unselected: gui.icon_sunny_o
				text_style:      gui.theme().icon3
				selected:        app.light_theme
				padding:         gui.padding_small
				on_click:        fn (_ &gui.ToggleCfg, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[IconFontApp]()
					app.light_theme = !app.light_theme
					theme := if app.light_theme {
						gui.theme_light_no_padding
					} else {
						gui.theme_dark_no_padding
					}
					w.set_theme(theme)
				}
			),
		]
	)
}
