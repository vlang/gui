# 12 Inputs

An input is a text input field that allows users to enter and edit text.
It supports single-line and multiline modes, text selection, undo/redo,
copy/paste/cut operations, and various keyboard shortcuts for navigation
and editing.

See also: `examples/inputs.v` for a runnable showcase.

## Overview

The `input` view creates an editable text field with:

- **Focus management**: Input fields require an `id_focus` value > 0 to
  enable editing. Fields without `id_focus` or with `id_focus: 0` are
  read-only.
- **State management**: Since views are stateless, the window maintains
  input state (cursor position, selection, undo/redo stacks) in a map keyed
  by `id_focus`.
- **Text editing**: Supports insertion, deletion, selection, undo/redo,
  copy/paste/cut.
- **Keyboard shortcuts**: Comprehensive keyboard navigation and editing
  shortcuts (see below).
- **Modes**: Single-line mode (default) or multiline mode with text
  wrapping.
- **Password mode**: Can mask input characters with '\*'s (copy is disabled
  when `is_password: true`).
- **Placeholder text**: Shows placeholder text when the input is empty.
- **Icons**: Optional icon that can be clicked.

## InputCfg

The `input` view is created with an `InputCfg` structure. Important fields:

### Content and behavior

- `id string` --- Optional identifier for the view.
- `text string` --- The current text content to display/edit.
- `placeholder string` --- Text shown when `text` is empty.
- `icon string` --- Optional icon constant displayed on the right side.
- `mode InputMode` --- Either `.single_line` (default) or `.multiline`
  (enables text wrapping and newlines).
- `is_password bool` --- When `true`, displays '\*' instead of actual
  characters. Copy operation is disabled.
- `disabled bool` --- When `true`, input won't accept input.
- `invisible bool` --- When `true`, removes from layout/paint.

### Callbacks

- `on_text_changed fn (&Layout, string, &mut Window)` --- Called whenever the
  text changes. **Required for editing**: input fields without this callback
  are read-only. You should update your state with the new text value.
- `on_enter fn (&Layout, mut Event, &mut Window)` --- Called when Enter is
  pressed. If not provided and `mode: .multiline`, Enter inserts a newline
  instead.
- `on_click_icon fn (&Layout, mut Event, mut Window)` --- Called when the
  icon is clicked (if `icon` is provided).

### Focus and interaction

- `id_focus u32` --- **Required for editing**: must be > 0 to enable
  keyboard input and editing. A value of 0 makes the field read-only.
  Also determines tab order when using keyboard navigation.

### Styling

- Colors:
  - `color Color` --- Interior color (defaults to theme's
    `input_style.color`)
  - `color_hover Color` --- Interior color while hovered (defaults to
    theme's `input_style.color_hover`)
  - `color_border Color` --- Border color (defaults to theme's
    `input_style.color_border`)
  - `color_border_focus Color` --- Border color when focused (defaults to
    theme's `input_style.color_border_focus`)
- Text styles:
  - `text_style TextStyle` --- Style for the text content (defaults to
    theme's `input_style.text_style`)
  - `placeholder_style TextStyle` --- Style for placeholder text (defaults
    to theme's `input_style.placeholder_style`)
  - `icon_style TextStyle` --- Style for the icon (defaults to theme's
    `input_style.icon_style`)
- Padding and radius:
  - `padding Padding` --- Interior padding (defaults to theme's
    `input_style.padding`)
  - `padding_border Padding` --- Border padding (defaults to theme's
    `input_style.padding_border`)
  - `radius f32` --- Corner radius for interior (defaults to theme's
    `input_style.radius`)
  - `radius_border f32` --- Corner radius for border (defaults to theme's
    `input_style.radius_border`)
- Sizing and layout:
  - `sizing Sizing` --- Standard sizing (`fit`, `fill`, `fixed`,
    combinations)
  - `width`, `height`, `min_width`, `min_height`, `max_width`,
    `max_height f32` --- Size constraints
  - `fill bool` --- Fill interior rectangle (defaults to theme's
    `input_style.fill`)
  - `fill_border bool` --- Fill border rectangle (defaults to theme's
    `input_style.fill_border`)

## Interaction model

### Focus

- An input field must have `id_focus > 0` to be editable.
- Use `w.set_id_focus(id)` to programmatically set focus to a field.
- The border color changes to `color_border_focus` when focused.
- Tab key navigation respects the `id_focus` ordering.

### Text editing

- **Character input**: Typing inserts characters at the cursor position.
- **Selection**: Click and drag, or use Shift+arrow keys to select text.
- **Replacement**: When text is selected, typing replaces the selection.
- **Placeholder**: Placeholder text disappears as soon as you start typing.

### Keyboard shortcuts

#### Navigation

- **Left/Right arrow** --- Move cursor left/right one character
- **Ctrl+Left** (Cmd+Left on Mac) --- Move to start of line; if at start,
  move up one line
- **Ctrl+Right** (Cmd+Right on Mac) --- Move to end of line; if at end,
  move down one line
- **Alt+Left** (Option+Left on Mac) --- Move to end of previous word
- **Alt+Right** (Option+Right on Mac) --- Move to start of next word
- **Home** --- Move cursor to start of text
- **End** --- Move cursor to end of text
- **Shift + any navigation key** --- Extend selection

#### Selection

- **Ctrl+A** (Cmd+A on Mac) --- Select all text
- **Left/Right arrow** (when text is selected) --- Move cursor to beginning
  or end of selection

#### Editing

- **Delete** --- Delete character after cursor (or selected text)
- **Backspace** --- Delete character before cursor (or selected text)
- **Enter** --- If `on_enter` is provided, triggers the callback. Otherwise,
  in multiline mode, inserts a newline. In single-line mode, does nothing
  (unless `on_enter` is provided).

#### Clipboard operations

- **Ctrl+C** (Cmd+C on Mac) --- Copy selected text (disabled when
  `is_password: true`)
- **Ctrl+X** (Cmd+X on Mac) --- Cut selected text (disabled when
  `is_password: true`)
- **Ctrl+V** (Cmd+V on Mac) --- Paste text from clipboard

#### Undo/Redo

- **Ctrl+Z** (Cmd+Z on Mac) --- Undo last change
- **Ctrl+Shift+Z** (Cmd+Shift+Z on Mac) --- Redo last undone change

#### Other

- **Escape** --- Unselect all text

## Basic example

A simple input field that updates state on text changes:

```v
import gui

struct App {
mut:
	name string
}

fn main() {
	mut window := gui.window(
		title:   'Input Demo'
		state:   &App{}
		width:   400
		height:  200
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
			w.set_id_focus(1)
		}
	)
	window.run()
}

fn main_view(mut w gui.Window) gui.View {
	mut app := w.state[App]()

	return gui.column(
		padding: gui.theme().padding_medium
		content: [
			gui.input(
				id_focus:        1
				text:            app.name
				placeholder:     'Enter your name...'
				min_width:       200
				max_width:       200
				on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
					mut app := w.state[App]()
					app.name = s
				}
			),
		]
	)
}
```

## Read-only input

Inputs without `on_text_changed` or with `id_focus: 0` are read-only:

```v
import gui

gui.input(
	id_focus: 0 // Makes it read-only
	text:     'This text cannot be edited'
)
```

Or simply omit `on_text_changed`:

```v
import gui

gui.input(
	id_focus: 1
	text:     'This text cannot be edited'
	// No on_text_changed callback = read-only
)
```

## Password input

Use `is_password: true` to mask the input:

```v
import gui

struct App {
mut:
	password string
}

mut app := App{}

gui.input(
	id_focus:        1
	text:            app.password
	placeholder:     'Enter password'
	is_password:     true
	min_width:       200
	max_width:       200
	on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
		mut app := w.state[App]()
		app.password = s
	}
)
```

Note: Copy operation is disabled when `is_password: true` for security.

## Multiline input

Set `mode: .multiline` to enable multiple lines:

```v
import gui

struct App {
mut:
	description string
}

mut app := App{}
gui.input(
	id_focus:        1
	text:            app.description
	placeholder:     'Enter description...'
	mode:            .multiline
	min_width:       300
	min_height:      100
	on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
		mut app := w.state[App]()
		app.description = s
	}
)
```

In multiline mode, Enter inserts a newline unless `on_enter` is provided.

## Input with Enter key handler

Use `on_enter` to capture the Enter key:

```v
import gui

struct App {
mut:
	query string
}

mut app := App{}
gui.input(
	id_focus:        1
	text:            app.query
	placeholder:     'Search...'
	on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
		mut app := w.state[App]()
		app.query = s
	}
	on_enter:        fn (_ &gui.Layout, mut e gui.Event, w &gui.Window) {
		mut app := w.state[App]()
		// Perform search with app.query
		println('Searching for: ${app.query}')
	}
)
```

## Input with icon

Add a clickable icon on the right side:

```v
import gui

struct App {
mut:
	search_text string
}

mut app := App{}
gui.input(
	id_focus:        1
	text:            app.search_text
	placeholder:     'Search...'
	icon:            gui.icon_search
	on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
		mut app := w.state[App]()
		app.search_text = s
	}
	on_click_icon:   fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
		mut app := w.state[App]()
		println('Icon clicked! Searching for: ${app.search_text}')
	}
)
```

## Styling (Themes)

Inputs use theme defaults, but you can override colors, padding, and radius:

```v
import gui

struct App {
mut:
	value string
}

mut app := App{}
gui.input(
	id_focus:           1
	text:               app.value
	color:              gui.rgb(250, 250, 250)
	color_border:       gui.rgb(200, 200, 200)
	color_border_focus: gui.rgb(100, 150, 255)
	padding:            gui.padding_medium
	padding_border:     gui.padding_small
	radius:             8
	radius_border:      10
	on_text_changed:    fn (_ &gui.Layout, s string, w &gui.Window) {
		mut app := w.state[App]()
		app.value = s
	}
)
```

## Input state management

The window maintains input state (cursor position, selection, undo/redo) for
each input field keyed by `id_focus`. This state includes:

- **Cursor position**: Current position of the text cursor (in runes from
  start of text)
- **Selection**: Start and end positions of selected text
- **Undo stack**: History of changes for undo operation
- **Redo stack**: History of undone changes for redo operation

This state is automatically managed by the input view. You don't need to
manually manage cursor positions or selections; the input handles all of
that internally.

The state is cleared when a new view tree is introduced (when
`w.update_view()` is called with a different view function).

## Tips

- **Always provide `on_text_changed`**: Without it, the input is read-only
  even if `id_focus > 0`.
- **Set initial focus**: Use `w.set_id_focus(id)` in `on_init` to set
  initial keyboard focus.
- **Tab order**: Use sequential `id_focus` values (1, 2, 3, ...) to
  establish tab navigation order.
- **State updates**: In `on_text_changed`, update your app state with the
  new text value so the input reflects the change.
- **Multiline sizing**: For multiline inputs, set `min_height` to ensure
  adequate space.
- **Fixed-width single-line**: When using `sizing.width: .fixed` in
  single-line mode, character input is automatically clamped to fit the
  width.
- **Password security**: Copy is disabled when `is_password: true` to
  prevent clipboard leaks.
- **Undo/redo**: Each input field maintains its own undo/redo stack,
  independent of other fields.

## See also

- `03-Views.md` --- background on views, containers, and sizing
- `07-Buttons.md` --- similar styling patterns (border/interior)
- `08-Container-View.md` --- understanding the underlying container
  structure
- `examples/inputs.v` --- comprehensive runnable examples