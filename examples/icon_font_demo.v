import gui

// Icon Font Demo
// =============================

@[heap]
struct IconFontApp {
pub mut:
	light_theme bool
	select_size string = 'x-large'
	longest     f32
	search      string
	icons       []&gui.View
}

fn main() {
	mut window := gui.window(
		title:   'Icon Font'
		state:   &IconFontApp{}
		width:   800
		height:  600
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
			w.set_id_focus(2)
		}
	)
	window.set_theme(gui.theme_dark_no_padding)
	window.run()
}

fn main_view(mut window gui.Window) &gui.View {
	w, h := window.window_size()
	// app := window.state[IconFontApp]()

	return gui.row(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		spacing: 0
		content: [
			side_panel(mut window),
			icon_catalog(mut window),
		]
	)
}

fn side_panel(mut w gui.Window) &gui.View {
	mut app := w.state[IconFontApp]()
	return gui.column(
		id:      'side-panel'
		color:   gui.theme().color_interior
		fill:    true
		sizing:  gui.fit_fill
		padding: gui.padding_large
		content: [
			gui.radio_button_group_column(
				options:   [
					gui.radio_option('tiny', 'tiny'),
					gui.radio_option('small', 'small'),
					gui.radio_option('medium', 'medium'),
					gui.radio_option('large', 'large'),
					gui.radio_option('x-large', 'x-large'),
				]
				value:     app.select_size
				on_select: fn [mut app] (value string, mut _ gui.Window) {
					app.select_size = value
					app.icons.clear()
				}
			),
			search_box(app.search),
			gui.column(sizing: gui.fill_fill),
			toggle_theme(app),
		]
	)
}

fn search_box(text string) &gui.View {
	return gui.input(
		text:            text
		id_focus:        2
		radius:          gui.radius_large
		radius_border:   gui.radius_large
		padding:         gui.pad_tblr(5, 10)
		min_width:       100
		max_width:       100
		padding_border:  gui.padding_one
		color_border:    gui.theme().color_border
		placeholder:     'Search'
		on_text_changed: fn (_ &gui.InputCfg, s string, mut w gui.Window) {
			mut app := w.state[IconFontApp]()
			app.search = s
			app.icons.clear()
		}
	)
}

fn icon_catalog(mut w gui.Window) &gui.View {
	mut app := w.state[IconFontApp]()
	icon_text_style := match app.select_size {
		'tiny' { gui.theme().icon6 }
		'x-small' { gui.theme().icon5 }
		'small' { gui.theme().icon4 }
		'large' { gui.theme().icon2 }
		'x-large' { gui.theme().icon1 }
		else { gui.theme().icon3 }
	}

	// find the longest text
	if app.longest == 0 {
		for s in gui.icons_map.keys() {
			app.longest = f32_max(gui.get_text_width(s, gui.theme().n4, mut w), app.longest)
		}
	}

	// create rows of icons/text
	if app.icons.len == 0 {
		// Break the icons_maps into rows
		chunks := chunk_map(gui.icons_map, app.search, 4)

		for chunk in chunks {
			mut icons := []&gui.View{}
			for key, val in chunk {
				icons << gui.column(
					min_width: app.longest
					h_align:   .center
					content:   [
						gui.text(text: val, text_style: icon_text_style),
						gui.text(text: key, text_style: gui.theme().n4),
					]
				)
			}
			app.icons << gui.row(
				spacing: 0
				content: icons
			)
		}
	}

	return gui.column(
		id:        'icons'
		id_focus:  1
		id_scroll: 1
		spacing:   gui.spacing_large
		sizing:    gui.fill_fill
		padding:   gui.padding_medium
		content:   app.icons
	)
}

// maybe this should be a standard library function?
fn chunk_map[K, V](input map[K]V, search string, chunk_size int) []map[K]V {
	mut chunks := []map[K]V{}
	mut current_chunk := map[K]V{}
	mut count := 0

	for key, value in input {
		if search.len > 0 && !key.contains(search) {
			continue
		}
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

fn toggle_theme(app &IconFontApp) &gui.View {
	return gui.row(
		h_align: .end
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			gui.toggle(
				text_select:   gui.icon_moon
				text_unselect: gui.icon_sunny_o
				text_style:    gui.theme().icon3
				select:        app.light_theme
				padding:       gui.padding_small
				on_click:      fn (_ &gui.ToggleCfg, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[IconFontApp]()
					app.light_theme = !app.light_theme
					theme := if app.light_theme {
						gui.theme_light_no_padding
					} else {
						gui.theme_dark_no_padding
					}
					w.set_theme(theme)
					app.icons.clear()
				}
			),
		]
	)
}
