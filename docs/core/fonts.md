# Fonts

v-gui uses system fonts by default and provides an embedded Feather Icons
font for UI icons.

## Default Fonts

v-gui uses the platform's default system font for text rendering. This
ensures:

- **Native appearance**: Text matches other applications on the platform
- **Broad glyph coverage**: System fonts support international scripts and
  emoji
- **No installation**: No font files to bundle or install

### Embedded Icon Font

Feather Icons font is embedded for UI icons (checkmarks, arrows, settings,
etc.). You don't need to install or bundle this separately.

## TextStyle

The `TextStyle` struct defines text appearance:

```oksyntax
pub struct TextStyle {
pub:
	family         string               // Font family or path to TTF/OTF
	color          Color                // Text color
	size           f32                  // Font size in points
	line_spacing   f32                  // Additional spacing between lines
	letter_spacing f32                  // Letter spacing
	underline      bool                 // Underline text
	strikethrough  bool                 // Strikethrough text
	features       &vglyph.FontFeatures // Advanced font features
}
```

## Using System Fonts

System fonts are used by default. To use the platform's default font,
simply don't specify a `family`:

```v
import gui

gui.text(
	text:       'Hello, system font!'
	text_style: gui.theme().text_style // Uses system font by default
)
```

Or explicitly set to empty string:

```v
import gui

gui.text(
	text:       'System font'
	text_style: gui.TextStyle{
		...gui.theme().text_style
		family: '' // Explicitly use system font
	}
)
```

## Using Custom Fonts

Point `family` to a TTF or OTF file path:

```v
import gui

gui.text(
	text:       'Custom font'
	text_style: gui.TextStyle{
		...gui.theme().text_style
		family: '/path/to/MyFont-Regular.ttf'
	}
)
```

If you provide a "Regular" face, v-gui attempts to locate Bold, Italic, and
Mono variants automatically.

## Text Size Presets

Themes provide H1-H6 style size presets for consistency:

```oksyntax
gui.text(text: 'Large heading', text_style: gui.theme().n1)
gui.text(text: 'Subheading', text_style: gui.theme().n2)
gui.text(text: 'Body text',text_style: gui.theme().n3)  // Default
gui.text(text: 'Small text', text_style: gui.theme().n4)
gui.text(text: 'Tiny text', text_style: gui.theme().n5)
```

Variants:
- `n1-n6`: Normal
- `b1-b6`: Bold
- `i1-i6`: Italic
- `m1-m6`: Monospace
- `icon1-icon6`: Icon font

## Icon Fonts

v-gui includes Feather Icons for common UI symbols.

### Render an Icon

```v
import gui

gui.text(
	text:       gui.icon_check // Icon glyph
	text_style: gui.TextStyle{
		...gui.theme().text_style
		family: gui.font_file_icon
		size:   18
	}
)
```

### Available Icons

Icons are exposed via `icon_*` constants in `gui.icons_map`:

```oksyntax
icon_check
icon_x
icon_chevron_right
icon_chevron_left
icon_menu
icon_settings
// ...and many more
```

See `examples/icon_font_demo.v` for a complete icon catalog.

## Text Style Properties

### Size

Font size in points (not pixels):

```oksyntax
text_style: gui.TextStyle{
	...gui.theme().text_style
	size: 16  // 16 point font
}
```

### Line Spacing

Additional spacing between lines:

```oksyntax
text_style: gui.TextStyle{
	...gui.theme().text_style
	line_spacing: 4  // 4 pixels extra between lines
}
```

### Color

Text color:

```v
import gui

struct App {}

fn main() {
	text_style := gui.TextStyle{
		...gui.theme().text_style
		color: gui.rgb(255, 100, 0) // Orange text
	}
}
```

### Text Decorations

Underline and strikethrough:

```oksyntax
text_style: gui.TextStyle{
	...gui.theme().text_style
	underline: true
	strikethrough: true
}
```

### Font Features

Advanced font features (OpenType features and variation axes) can be configured via the
`features` field.

```oksyntax
text_style: gui.TextStyle{
	...gui.theme().text_style
	features: &vglyph.FontFeatures{
		// Configure axes and features here
	}
}
```



## Common Patterns

### Heading and Body Text

```v
import gui

gui.column(
	content: [
		gui.text(
			text:       'Document Title'
			text_style: gui.theme().b1 // Large, bold
		),
		gui.text(
			text:       'Subtitle'
			text_style: gui.theme().n2 // Medium, normal
		),
		gui.text(
			text:       'Body paragraph...'
			text_style: gui.theme().n3 // Default size
		),
	]
)
```

### Code Block

```oksyntax
gui.text(
	text:       'fn main() { ... }'
	text_style: gui.theme().m4  // Monospace preset
)
```

### Colored Label

```v
import gui

gui.text(
	text:       'Error!'
	text_style: gui.TextStyle{
		...gui.theme().b3
		color: gui.rgb(255, 59, 48) // Red
	}
)
```

### Icon Button

```v
import gui

gui.button(
	content: [
		gui.text(
			text:       gui.icon_gear
			text_style: gui.theme().icon3
		),
		gui.text(text: 'Settings'),
	]
)
```

## Text Rendering

v-gui uses vglyph for text rendering, which provides:
- **Complex text shaping**: Ligatures, kerning, etc.
- **Bidirectional text**: Left-to-right and right-to-left
- **International scripts**: Proper rendering of Arabic, Thai, etc.
- **Emoji support**: Color emoji rendering (platform-dependent)

## Troubleshooting

### Missing Glyphs

If characters don't render (e.g., Chinese, Japanese, Korean):

- Switch to system font: `family: ''`
- Use a custom font with required glyph coverage

### Inconsistent Layouts Across Platforms

- Prefer embedded fonts for uniform metrics
- Pin a specific custom font across platforms

### Icons Not Showing

- Ensure `family: gui.font_file_icon`
- Check icon constant exists in `gui.icons_map`

## Related Topics

- **[Themes](themes.md)** - Text style presets in themes
- **[Styles](styles.md)** - Component text styles
- **[Text Component](../components/text-and-images.md)** - Text view
  details

## Examples

- `examples/system_font.v` - System vs embedded fonts
- `examples/fonts.v` - Font basics and styling
- `examples/icon_font_demo.v` - Icon font catalog