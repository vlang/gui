# Text and Images

Display text and images in your UI.

## text

Renders text with full styling support.

### Basic Usage

```v
import gui

gui.text(text: 'Hello, v-gui!')
```

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `text` | `string` | Text content to display |
| `text_style` | `TextStyle` | Font, size, color, weight |
| `mode` | `TextMode` | Single-line or multi-line |
| `width` | `f32` | Text wrapping width |

### Text Styling

Use `text_style` to control appearance:

```v
import gui

gui.text(
	text:       'Styled Text'
	text_style: gui.TextStyle{
		...gui.theme().text_style
		size:   18
		color:  gui.rgb(255, 100, 0)
		weight: 700 // Bold
	}
)
```

### Theme Presets

Use built-in text style presets:

```v
import gui

gui.column(
	content: [
		gui.text(text: 'Heading', text_style: gui.theme().b1),
		gui.text(text: 'Subheading', text_style: gui.theme().n2),
		gui.text(text: 'Body text', text_style: gui.theme().n3),
		gui.text(text: 'Small print', text_style: gui.theme().n5),
	]
)
```

Presets:
- `n1-n6`: Normal text, sizes H1-H6
- `b1-b6`: Bold text
- `i1-i6`: Italic text
- `m1-m6`: Monospace text
- `icon1-icon6`: Icon font

### Multi-line Text

Text wraps automatically when `width` is set:

```v
import gui

gui.text(
	text:  'This is a long paragraph that will wrap to multiple lines when it exceeds the specified width.'
	width: 300
	mode:  .multiline
)
```

### Passwords

Hide text for password inputs:

```oksyntax
gui.text(
	text:        user_password
	is_password: true
)
```

## image

Displays images from file paths or memory.

### Basic Usage

```v
import gui

gui.image(
	path:   '/path/to/image.png'
	width:  200
	height: 200
)
```

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `path` | `string` | File path to image |
| `width`, `height` | `f32` | Display dimensions |
| `scaling` | `ImageScaling` | How to fit: `.fit`, `.fill`, `.stretch` |

### Image Scaling

Control how images fit within dimensions:

**Fit (preserve aspect ratio)**:
```oksyntax
gui.image(
	path:    '/path/to/photo.jpg'
	width:   200
	height:  150
	scaling: .fit // Default: maintains aspect ratio
)
```

**Fill (crop to fill)**:
```oksyntax
gui.image(
	path:    '/path/to/photo.jpg'
	width:   200
	height:  150
	scaling: .fill // Crops to fill dimensions
)
```

**Stretch (distort if needed)**:
```oksyntax
gui.image(
	path:    '/path/to/photo.jpg'
	width:   200
	height:  150
	scaling: .stretch // Stretches to exact dimensions
)
```

### Image in Buttons

Combine images with text in buttons:

```v
import gui

gui.button(
	content: [
		gui.image(path: 'icon.png', width: 16, height: 16),
		gui.text(text: 'Save'),
	]
)
```

### Icons

Use icon font for scalable icons:

```v
import gui

gui.text(
	text:       gui.icon_check
	text_style: gui.TextStyle{
		...gui.theme().text_style
		family: gui.font_file_icon
		size:   20
	}
)
```

See [Fonts](../core/fonts.md#icon-fonts) for icon catalog.

## rtf

Rich text with multiple styles (attributed strings).

### Basic Usage

```oksyntax
gui.rtf(
	text:   'Hello World'
	styles: [
		gui.RichTextStyle{range: [0, 5], weight: 700}, // "Hello" bold
		gui.RichTextStyle{range: [6, 11], color: gui.rgb(255, 0, 0)}, // "World" red
	]
)
```

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `text` | `string` | Full text content |
| `styles` | `[]RichTextStyle` | Style ranges |
| `base_style` | `TextStyle` | Default style |

### Style Ranges

Apply different styles to text ranges:

```oksyntax
gui.rtf(
	text:       'Normal Bold Italic'
	base_style: gui.theme().text_style
	styles:     [
		gui.RichTextStyle{
			range:  [7, 11] // "Bold"
			weight: 700
		},
		gui.RichTextStyle{
			range:  [12, 18] // "Italic"
			italic: true
		},
	]
)
```

### Use Cases

- Syntax highlighting
- Formatted text editors
- Mixed-style labels
- Markdown rendering

## Common Patterns

### Label with Icon

```v
import gui

gui.row(
	spacing: 5
	content: [
		gui.text(text: gui.icon_check, text_style: gui.theme().icon3),
		gui.text(text: 'Success'),
	]
)
```

### Multiline Paragraph

```v
import gui

gui.text(
	text:  'Lorem ipsum dolor sit amet, consectetur adipiscing elit. ' +
		'Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.'
	width: 400
	mode:  .multiline
)
```

### Avatar Image

```oksyntax
gui.image(
	path:    '/path/to/avatar.jpg'
	width:   48
	height:  48
	scaling: .fill
	radius:  24 // Circular
)
```

### Colored Text Badge

```v
import gui

gui.row(
	padding: gui.Padding{4, 8, 4, 8}
	fill:    true
	color:   gui.rgb(0, 120, 255)
	radius:  12
	content: [
		gui.text(
			text:       'New'
			text_style: gui.TextStyle{
				...gui.theme().text_style
				color: gui.rgb(255, 255, 255)
				size:  12
			}
		),
	]
)
```

## Related Topics

- **[Fonts](../core/fonts.md)** - Text styling and fonts
- **[Themes](../core/themes.md)** - Text style presets
- **[Containers](containers.md)** - Layout with text and images