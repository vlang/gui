# Theme Types

Theme and styling type definitions.

## Theme

Complete theme configuration:

```oksyntax
pub struct Theme {
pub:
	cfg              ThemeCfg
	name             string
	
	// Global colors
	color_background Color
	color_panel      Color
	color_interior   Color
	color_hover      Color
	color_focus      Color
	color_active     Color
	color_border     Color
	color_border_focus Color
	color_select     Color
	color_text       Color
	
	// Component styles
	button_style        ButtonStyle
	input_style         InputStyle
	dialog_style        DialogStyle
	menubar_style       MenubarStyle
	progress_bar_style  ProgressBarStyle
	scrollbar_style     ScrollbarStyle
	toggle_style        ToggleStyle
	tree_style          TreeStyle
	// ...additional component styles
	
	// Text presets
	text_style      TextStyle
	text_style_bold TextStyle
	n1, n2, n3, n4, n5, n6       TextStyle  // Normal sizes
	b1, b2, b3, b4, b5, b6       TextStyle  // Bold sizes
	i1, i2, i3, i4, i5, i6       TextStyle  // Italic sizes
	m1, m2, m3, m4, m5, m6       TextStyle  // Monospace sizes
	icon1, icon2, icon3, icon4, icon5, icon6 TextStyle  // Icon sizes
	
	// Layout constants
	padding         Padding
	padding_border  Padding
	radius          f32
	radius_border   f32
	spacing         f32
}
```

## ThemeCfg

Compact theme configuration for `theme_maker()`:

```oksyntax
pub struct ThemeCfg {
pub:
	name               string @[required]
	
	// Colors
	color_background   Color
	color_panel        Color
	color_interior     Color
	color_hover        Color
	color_focus        Color
	color_active       Color
	color_border       Color
	color_border_focus Color
	color_select       Color
	color_text         Color
	
	// Layout
	padding            Padding
	padding_border     Padding
	radius             f32
	radius_border      f32
	spacing            f32
	
	// Text
	text_style         TextStyle
	
	// Window
	titlebar_dark      bool
}
```

## TextStyle

Text appearance configuration:

```oksyntax
pub struct TextStyle {
pub:
	family       string  // Font family or path
	size         f32     // Font size in points
	line_spacing f32     // Additional line spacing
	color        Color   // Text color
	weight       int     // Font weight (100-900)
	italic       bool    // Italic style
	monospace    bool    // Monospace variant
}
```

## Component Styles

### ButtonStyle

```oksyntax
pub struct ButtonStyle {
pub:
	color            Color
	color_background Color
	color_border     Color
	color_hover      Color
	color_focus      Color
	color_active     Color
	fill             bool
	fill_border      bool
	padding          Padding
	padding_border   Padding
	radius           f32
	text_style       TextStyle
}
```

### InputStyle

```oksyntax
pub struct InputStyle {
pub:
	color            Color
	color_background Color
	color_border     Color
	color_focus      Color
	color_select     Color
	fill             bool
	fill_border      bool
	padding          Padding
	padding_border   Padding
	radius           f32
	text_style       TextStyle
}
```

Additional component style structs follow similar patterns.

## Built-in Themes

### Dark Themes

```oksyntax
pub const (
	theme_dark_cfg            ThemeCfg
	theme_dark                Theme
	theme_dark_no_padding_cfg ThemeCfg
	theme_dark_no_padding     Theme
	theme_dark_bordered_cfg   ThemeCfg
	theme_dark_bordered       Theme
)
```

### Light Themes

```oksyntax
pub const (
	theme_light_cfg            ThemeCfg
	theme_light                Theme
	theme_light_no_padding_cfg ThemeCfg
	theme_light_no_padding     Theme
	theme_light_bordered_cfg   ThemeCfg
	theme_light_bordered       Theme
)
```

## Color

Color representation:

```oksyntax
pub struct Color {
pub:
	r u8
	g u8
	b u8
	a u8
}
```

### Color Functions

```oksyntax
pub fn rgb(r int, g int, b int) Color
pub fn rgba(r int, g int, b int, a int) Color
pub fn hex(value int) Color
```

## Theme Creation

Use `theme_maker()` to create themes:

```oksyntax
my_theme := gui.theme_maker(gui.ThemeCfg{
	name:             'custom'
	color_background: gui.rgb(28, 28, 30)
	color_panel:      gui.rgb(36, 36, 38)
	// ...additional config
})
```

## Related Topics

- **[Themes](../core/themes.md)** - Theme usage guide
- **[Styles](../core/styles.md)** - Component styling
- **[Fonts](../core/fonts.md)** - TextStyle details
