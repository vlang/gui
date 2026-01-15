# Views

A view is the fundamental UI building block in v-gui. Every button, menu,
text label, and panel is a view.

## The Three Primitives

Despite the variety of components available, there are only three primitive
view types:

1. **Containers** - Hold other views
2. **Text** - Display text
3. **Images** - Display bitmaps

Everything else is a composition of these three.

## Containers

Containers are rectangular regions that hold other views (containers, text,
or images). They come in three flavors based on their axis:

### Row (left-to-right axis)

Stacks children horizontally:

```v
import gui

gui.row(
	spacing: 5
	content: [
		gui.text(text: 'First'),
		gui.text(text: 'Second'),
		gui.text(text: 'Third'),
	]
)
```

Result: `[First] [Second] [Third]`

### Column (top-to-bottom axis)

Stacks children vertically:

```v
import gui

gui.column(
	spacing: 5
	content: [
		gui.text(text: 'First'),
		gui.text(text: 'Second'),
		gui.text(text: 'Third'),
	]
)
```

Result:
```
[First]
[Second]
[Third]
```

### Canvas (no axis)

Positions children using explicit coordinates (free-form):

```v
import gui

gui.canvas(
	width:   200
	height:  200
	content: [
		gui.text(text: 'Positioned', x: 10, y: 20),
		gui.text(text: 'Freely', x: 100, y: 100),
	]
)
```

## Essential Container Properties

### Padding

Inner margin between the container's border and its content.

```
        Container (row)
      +---------------------------------------------+
      |                 Padding Top                 |
      |   +----------------+   +----------------+   |
      | P |                |   |                | P |
      | a |                |   |                | a |
      | d |                | S |                | d |
      | d |                | p |                | d |
      | i |                | a |                | i |
      | n |   child view   | c |   child view   | n |
      | g |                | i |                | g |
      |   |                | n |                |   |
      | L |                | g |                | R |
      | e |                |   |                | i |
      | f |                |   |                | g |
      | t |                |   |                | h |
      |   +----------------+   +----------------+ t |
      |                Padding Bottom               |
      +---------------------------------------------+
```

Specified as `Padding{top, right, bottom, left}`:

```oksyntax
gui.column(
	padding: gui.Padding{5, 10, 5, 10}  // (top, right, bottom, left)
	content: [...]
)
```

Convenience constants:
- `padding_none`: `{0, 0, 0, 0}`
- `padding_one`: `{1, 1, 1, 1}`
- `padding_two`: `{2, 2, 2, 2}`
- `padding_small`: `{5, 5, 5, 5}`
- `padding_medium`: `{10, 10, 10, 10}`
- `padding_large`: `{15, 15, 15, 15}`

### Spacing

Gap between children. For rows, this is horizontal spacing; for columns,
vertical.

```oksyntax
gui.row(
	spacing: 10  // 10 logical pixels between each child
	content: [...]
)
```

### Sizing

Controls how a view determines its width and height. Three modes per axis:

- `fit` - Size to content
- `fill` - Grow or shrink to fill parent
- `fixed` - Use specified width/height

See [Sizing & Alignment](sizing-alignment.md) for details.

## Text

Text is its own primitive because text layout is complex:
- Bidirectional text (left-to-right, right-to-left)
- Line wrapping
- Font shaping (ligatures, kerning)
- Complex scripts (Arabic, Thai, etc.)

Basic text view:

```v
import gui

gui.text(
	text:       'Hello, v-gui!'
	text_style: gui.theme().b2 // Bold, size 2
)
```

Text wrapping:

```oksyntax
gui.text(
	text: 'This is a long text that will wrap to multiple lines...'
	width: 200  // Wrap at 200 logical pixels
)
```

Overflow handling:
- **Enable scrolling** in parent container
- **Enable clipping** on parent to hide overflow

Text is not a container - it displays text only.

## Images

The simplest view. Displays a bitmap or texture:

```v
import gui

gui.image(
	path:   '/path/to/image.png'
	width:  100
	height: 100
)
```

Images maintain aspect ratio by default.

## Compositions

Complex components are built from primitives. For example, a button is:

```
button = outer row (border/background)
           → inner row (button body)
              → content (typically text, but can be any views)
```

Because buttons are containers, they can hold any views:

```v
import gui

gui.button(
	content:  [
		gui.image(path: 'icon.png', width: 16, height: 16),
		gui.text(text: 'Click Me'),
	]
	on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
		println('Button clicked!')
	}
)
```

## View Lifecycle

Views are **stateless** and **ephemeral**. They exist only during layout
calculation:

1. View generator function is called
2. Function builds a View tree (pure function of state)
3. Layout engine converts View to Layout
4. Layout is rendered
5. View objects are discarded

On the next update (user event, timer, etc.), the process repeats with a
fresh View tree.

## Stateless Benefits

- **Predictable**: View is always a function of application state
- **No stale state**: Can't have out-of-sync UI
- **Easy to test**: Pure functions
- **Thread-safe**: No shared mutable state in views

## Transient UI State

Some state doesn't belong in application state (focus, selection,scroll
position). This is managed by `ViewState`:

```oksyntax
// v-gui manages these automatically
view_state.focused_id
view_state.scroll_positions[id]
view_state.text_selection
```

You rarely interact with ViewState directly - components handle it.

## Common Patterns

### Conditional Rendering

Use V's `if` expressions to conditionally include views:

```oksyntax
content: [
	gui.text(text: 'Always visible'),
	if show_extra {
		gui.text(text: 'Conditionally visible')
	},
]
```

### Loops

Use `map` to generate views from data:

```oksyntax
content: items.map(fn (item string) gui.View {
	return gui.text(text: item)
})
```

### Nested Layouts

Combine rows and columns:

```oksyntax
gui.column(
	content: [
		gui.row(content: [
			gui.text(text: 'Top-left'),
			gui.text(text: 'Top-right'),
		]),
		gui.row(content: [
			gui.text(text: 'Bottom-left'),
			gui.text(text: 'Bottom-right'),
		]),
	]
)
```

## Related Topics

- **[Layout](layout.md)** - How rows and columns work in detail
- **[Sizing & Alignment](sizing-alignment.md)** - Control element
  dimensions
- **[Components](../components/README.md)** - Available UI components
- **[Creating Custom Views](../guides/creating-custom-views.md)** - Build
  reusable components