# Themes

v-gui's theming system controls colors, paddings, radii, spacing, and text
styles across all components. Apply built-in themes or create custom ones
with minimal configuration.

## Quick Start

Apply a theme to your window:

```v
import gui

struct App {}

mut window := gui.window(
	width:   800
	height:  600
	state:   &App{}
	on_init: fn (mut w gui.Window) {
		w.set_theme(gui.theme_dark_bordered)
		w.update_view(main_view)
	}
)
```

Access the active theme anywhere:

```oksyntax
gui.text(
	text:       'Headline'
	text_style: gui.theme().b2  // Built-in bold preset
)

// Use theme colors for custom styling
layout.shape.color = gui.theme().color_hover
```

## Built-In Themes

Predefined themes ready to use:

**Dark themes**:
- `theme_dark` - Standard dark theme
- `theme_dark_no_padding` - Dark theme without padding
- `theme_dark_bordered` - Dark theme with borders

**Light themes**:
- `theme_light` - Standard light theme
- `theme_light_no_padding` - Light theme without padding
- `theme_light_bordered` - Light theme with borders

Switch themes at runtime:

```oksyntax
window.set_theme(gui.theme_light)
```

## Theme Anatomy

### Theme

The `Theme` struct is a fully materialized style configuration:

- **Global colors**: `color_background`, `color_panel`, `color_interior`,
  `color_hover`, `color_focus`, `color_active`, `color_border`,
  `color_select`
- **Per-component styles**: `button_style`, `input_style`,
  `menubar_style`, `dialog_style`, `progress_bar_style`,
  `scrollbar_style`, etc.
- **Text presets**: `n1..n6` (normal), `b1..b6` (bold), `i1..i6`
  (italic), `m1..m6` (mono), `icon1..icon6` (icon font)
- **Sizing constants**: `spacing_small`, `radius_medium`,
  `size_text_large`, etc.

### ThemeCfg

A compact configuration used to create a `Theme`. Specify only what you
need; all fields have defaults.

### Style Structs

Per-component style structs (defined in `styles.v`):
- `ButtonStyle`, `InputStyle`, `DialogStyle`, `MenubarStyle`, etc.
- Each contains colors, fill, padding, radius, spacing, text styles

## Creating Custom Themes

Use `theme_maker()` to generate a complete theme from a small config:

```v
import gui

pub fn my_brand_theme() gui.Theme {
	return gui.theme_maker(gui.ThemeCfg{
		name:               'my-brand'
		color_background:   gui.rgb(28, 28, 30)
		color_panel:        gui.rgb(36, 36, 38)
		color_interior:     gui.rgb(52, 52, 56)
		color_hover:        gui.rgb(70, 70, 78)
		color_focus:        gui.rgb(88, 88, 98)
		color_active:       gui.rgb(110, 110, 120)
		color_border:       gui.rgb(70, 70, 80)
		color_border_focus: gui.rgb(110, 140, 220)
		color_select:       gui.rgb(110, 140, 220)
		titlebar_dark:      true
		padding:            gui.padding_medium
		padding_border:     gui.padding_none
		radius:             gui.radius_medium
		radius_border:      gui.radius_border
		text_style:         gui.TextStyle{
			...gui.theme_dark_cfg.text_style
			// Override specific text properties here
		}
	})
}
```

Apply your custom theme:

```oksyntax
window.set_theme(my_brand_theme())
```

## Modifying Existing Themes

Start from a built-in theme config and override specific fields:

```v
import gui

pub fn my_theme() gui.Theme {
	return gui.theme_maker(gui.ThemeCfg{
		...gui.theme_dark_cfg // Start with dark theme
		name:             'my-custom-dark'
		color_background: gui.rgb(10, 10, 15) // Darker background
		radius:           gui.radius_large // Rounder corners
	})
}
```

Or modify a `Theme` after creation:

```oksyntax
mut t := gui.theme_dark
mut bs := t.button_style
bs.radius = 12  // Rounder buttons
t = gui.Theme{...t, button_style: bs}
window.set_theme(t)
```

## Text Presets

Themes provide H1-H6 style text presets for consistency:

**Normal** (`n1` - `n6`):
```oksyntax
gui.text(text: 'Large heading', text_style: gui.theme().n1)
gui.text(text: 'Subheading', text_style: gui.theme().n2)
gui.text(text: 'Body text', text_style: gui.theme().n3)  // Default
gui.text(text: 'Small text', text_style: gui.theme().n4)
```

**Bold** (`b1` - `b6`):
```oksyntax
gui.text(text: 'Bold headline', text_style: gui.theme().b2)
```

**Italic** (`i1` - `i6`):
```oksyntax
gui.text(text: 'Emphasized', text_style: gui.theme().i3)
```

**Monospace** (`m1` - `m6`):
```oksyntax
gui.text(text: 'Code sample', text_style: gui.theme().m4)
```

**Icon font** (`icon1` - `icon6`):
```oksyntax
gui.text(text: '\ue001', text_style: gui.theme().icon3)  // Icon glyph
```

## Per-View Style Overrides

Override styles for individual views without changing the theme:

```oksyntax
gui.button(
	text:  'Primary'
	style: gui.ButtonStyle{
		...gui.theme().button_style
		radius:       12  // Custom radius for this button only
		color_active: gui.rgb(0, 120, 255)  // Custom active color
	}
)
```

## Common Theme Properties

### Color Palette

- `color_background` - Window background
- `color_panel` - Panel/container background
- `color_interior` - Interior fill (buttons, inputs)
- `color_hover` - Hover state
- `color_focus` - Focused state
- `color_active` - Active/pressed state
- `color_border` - Default border color
- `color_border_focus` - Focused border color
- `color_select` - Selection highlight
- `color_text` - Default text color

### Sizing

- `padding` - Default padding: `padding_small`, `padding_medium`,
  `padding_large`
- `padding_border` - Border padding: `padding_none`, `padding_one`,
  `padding_two`
- `radius` - Corner radius: `radius_none`, `radius_small`,
  `radius_medium`, `radius_large`
- `spacing` - Gap between elements: `spacing_small`, `spacing_medium`,
  `spacing_large`

### Text Sizes

- `size_text_tiny` - Smallest text
- `size_text_x_small`
- `size_text_small`
- `size_text_medium` - Default
- `size_text_large`
- `size_text_x_large` - Largest text

## Runtime Theme Switching

Implement a theme toggle:

```v
import gui

struct App {
pub mut:
	use_dark bool = true
}

fn settings_view(window &gui.Window) gui.View {
	app := window.state[App]()
	return gui.column(
		content: [
			gui.button(
				content:  [gui.text(text: 'Toggle Theme')]
				on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[App]()
					app.use_dark = !app.use_dark
					theme := if app.use_dark {
						gui.theme_dark
					} else {
						gui.theme_light
					}
					w.set_theme(theme)
				}
			),
		]
	)
}
```

## Tips

- **Start simple**: Use a built-in theme first
- **Override sparingly**: Start from an existing config and change only
  what you need
- **Use theme_maker**: Generates consistent themes from compact configs
- **Container transparency**: `theme_maker` makes containers transparent by
  default
- **Text line spacing**: Adjust `spacing_text` on the theme to control line
  height
- **System fonts**: Set `text_style.family: ''` to use the platform default
  font

## Related Topics

- **[Styles](styles.md)** - Per-component style structs
- **[Fonts](fonts.md)** - Text styling and font system
- **[Colors](../api/utility-functions.md)** - Color utilities