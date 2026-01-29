import gui

// Markdown View Demo
// ==================
// Demonstrates rendering markdown as styled rich text.

const markdown_source = '# Markdown Demo

This is a **bold** statement and this is *italic* text.

## Features

Here is some `inline code` in a paragraph.

### Lists

Unordered list:
- First item
- Second item
- Third item

Ordered list:
1. Step one
2. Step two
3. Step three

---

## Code Block

```
fn main() {
    println("Hello, World!")
}
```

## Links

Visit [V Language](https://vlang.io) for more info.

### All Headers

# H1 Header
## H2 Header
### H3 Header
#### H4 Header
##### H5 Header
###### H6 Header

That is all!'

fn main() {
	mut window := gui.window(
		width:   500
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

	return gui.column(
		width:     w
		height:    h
		sizing:    gui.fixed_fixed
		padding:   gui.theme().padding_large
		id_focus:  1
		id_scroll: 1
		content:   [
			gui.markdown(
				source: markdown_source
				mode:   .wrap
			),
		]
	)
}
