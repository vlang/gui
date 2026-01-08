import gui

// Multilingual Text Demo
// =============================
// Demonstrates rendering of "Hello World" in 10 different languages.

@[heap]
struct MultilingualApp {
pub mut:
	languages []LanguageEntry
}

struct LanguageEntry {
	name string
	text string
}

fn main() {
	mut app := &MultilingualApp{
		languages: [
			LanguageEntry{'English', 'Hello World'},
			LanguageEntry{'French', 'Bonjour le monde'},
			LanguageEntry{'Polish', 'Witaj świecie'},
			LanguageEntry{'Russian', 'Привет, мир'},
			LanguageEntry{'Japanese', 'こんにちは世界'},
			LanguageEntry{'Arabic', 'مرحبا بالعالم'},
			LanguageEntry{'Chinese', '你好，世界'},
			LanguageEntry{'Korean', '안녕하세요 세계'},
			LanguageEntry{'Hindi', 'नमस्ते दुनिया'},
			LanguageEntry{'Thai', 'สวัสดีชาวโลก'},
			LanguageEntry{'Greek', 'Γεια σου κόσμε'},
			LanguageEntry{'Hebrew', 'שלום לך עולם'},
		]
	}

	mut window := gui.window(
		title:   'Multilingual Text'
		state:   app
		width:   600
		height:  700
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(mut window gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[MultilingualApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		padding: gui.theme().padding_large
		spacing: gui.theme().spacing_medium
		content: [
			gui.text(
				text:       'Multilingual Support'
				text_style: gui.theme().b1
			),
			gui.column(
				sizing:    gui.fill_fill
				id_scroll: 1 // Enable scrolling if window is small
				content:   app.languages.map(create_language_row(it))
			),
		]
	)
}

fn create_language_row(entry LanguageEntry) gui.View {
	return gui.row(
		sizing:  gui.fill_fit
		spacing: 20
		v_align: .middle
		content: [
			gui.text(
				text:       entry.name
				min_width:  150
				text_style: gui.theme().b2
			),
			gui.text(
				text:       entry.text
				text_style: gui.theme().n1
			),
		]
	)
}
