import gui

// Multiline Input Demo
// =============================

@[heap]
struct MultilineApp {
mut:
	text string = the_text
}

fn main() {
	mut window := gui.window(
		title:        'Multiline Input Demo'
		state:        &MultilineApp{}
		width:        400
		height:       300
		cursor_blink: true
		on_init:      fn (mut w gui.Window) {
			w.update_view(main_view)
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
				id_focus:        1
				id_scroll:       1
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

const the_text = 'This program allows testing of various keyboard navigation features for the input view.

Things to try:

- left/right - cursor movement. Cursor should wrap to next line.

- up/down - up/down cursor movements have subtle behaviors. For instance, moving the cursor to shorter line veritically should move the cursor to the end of line. Further vertical cursor movements should restore the cursor to column where vertical navigation started. In fixed with fonts, this is straightforward. In variable width fonts, there are no columns. Instead, the pixel offset is remembered and used to find the closest character position that corresponds to the pixel offset.

Lorem Ipsum:

On the other hand, we denounce with righteous indignation and dislike men who are so beguiled and demoralized by the charms of pleasure of the moment, so blinded by desire, that they cannot foresee the pain and trouble that are bound to ensue; and equal blame belongs to those who fail in their duty through weakness of will, which is the same as saying through shrinking from toil and pain. These cases are perfectly simple and easy to distinguish. In a free hour, when our power of choice is untrammelled and when nothing prevents our being able to do what we like best, every pleasure is to be welcomed and every pain avoided. But in certain circumstances and owing to the claims of duty or the obligations of business it will frequently occur that pleasures have to be repudiated and annoyances accepted. The wise man therefore always holds in these matters to this principle of selection: he rejects pleasures to secure other greater pleasures, or else he endures pains to avoid worse pains.'
