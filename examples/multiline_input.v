import gui

// Multiline Input Demo
// =============================
// Use this program to test cursor movement and text selections.
//
// #### Keyboard shortcuts (not final):
// - **left/right**    moves cursor left/right one character
// - **ctrl+left**     moves to start of line, if at start of line moves up one line
// - **ctrl+right**    moves to end of line, if at end of line moves down one line
// - **alt+left**      moves to end of previous word (option+left on Mac)
// - **alt+right**     moves to start of word (option+left on Mac)
// - **home**          move cursor to start of text
// - **end**           move cursor to end of text
// - Add shift to above shortcuts to select text
// ---
// - **ctrl+a**        selects all text (also **cmd+a** on Mac)
// - **ctrl+c**        copies selected text (also **cmd+c** on Mac)
// - **ctrl+v**        pastes text (also **cmd+v** on Mac)
// - **ctrl+x**        deletes text (also **cmd+x** on Mac)
// - **ctrl+z**        undo (also **cmd+z** on Mac)
// - **shift+ctrl+z**  redo (also **shift+cmd+z** on Mac)
// - **escape**        unselects all text
// - **delete**        deletes previous character
// - **backspace**     deletes previous character
//
// Mouse selection should work similar to other programs.
// Auto-scroll while drag-selecting text supported
//
const input_id_focus = 1
const input_id_scroll = 1

@[heap]
struct MultilineApp {
mut:
	text string
}

fn main() {
	mut window := gui.window(
		title:        'Multiline Input Demo'
		state:        &MultilineApp{}
		width:        400
		height:       300
		cursor_blink: true
		on_init:      fn (mut w gui.Window) {
			mut app := w.state[MultilineApp]()
			app.text = gui.lorem_generate(paragraphs: 10)
			w.update_view(main_view)
			w.set_id_focus(input_id_focus)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[MultilineApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		content: [
			gui.input(
				id_focus:        input_id_focus
				id_scroll:       input_id_scroll
				scroll_mode:     .vertical_only
				text:            app.text
				mode:            .multiline
				sizing:          gui.fill_fill
				on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
					mut app := w.state[MultilineApp]()
					app.text = s
				}
			),
		]
	)
}
