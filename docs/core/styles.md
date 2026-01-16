# Styles

Style structs define visual properties for each component type. Styles are
typically applied through themes, but can be overridden per-view.

## Style Structs

Each component has its own style struct defined in `styles.v`:

- `ButtonStyle`
- `InputStyle`
- `DialogStyle`
- `MenubarStyle`
- `ProgressBarStyle`
- `ScrollbarStyle`
- `SwitchStyle`
- `ToggleStyle`
- `TooltipStyle`
- `TreeStyle`
- And more...

## Common Style Properties

Most style structs share similar properties:

### Colors

- `color` - Primary color (text, icon)
- `color_background` - Background fill
- `color_border` - Border color
- `color_hover` - Hover state color
- `color_focus` - Focused state color
- `color_active` - Active/pressed state color

### Fill

- `fill` - Interior fill enabled
- `fill_border` - Border fill enabled

### Layout

- `padding` - Inner margin (`Padding{top, right, bottom, left}`)
- `spacing` - Gap between children
- `radius` - Corner radius (rounded corners)

### Text

- `text_style` - Font, size, color, etc. for text in the component

## Using Styles from Themes

Access component styles through the active theme:

```oksyntax
gui.button(
	style: gui.theme().button_style
	content: [...]
)
```

This is the default behavior - if you don't specify a style, the theme's
style is used automatically.

## Per-View Style Overrides

Override specific style properties for individual views:

```v
import gui

gui.button(
	content:     [gui.text(text: 'Custom Button')]
	radius:      12 // Override radius
	color_click: gui.rgb(255, 100, 0) // Override active color
)
```

Only specified properties are changed; others inherit from the theme.

## Example: ButtonStyle

```oksyntax
pub struct ButtonStyle {
pub:
	color            Color   // Text/icon color
	color_background Color   // Background color
	color_border     Color   // Border color
	color_hover      Color   // Hover state background
	color_focus      Color   // Focused state background
	color_active     Color   // Pressed state background
	fill             bool    // Fill background
	fill_border      bool    // Draw border
	padding          Padding // Inner padding
	padding_border   Padding // Border thickness
	radius           f32     // Corner radius
	text_style       TextStyle // Text properties
}
```

## Example: InputStyle

```oksyntax
pub struct InputStyle {
pub:
	color            Color
	color_background Color
	color_border     Color
	color_focus      Color  // Border color when focused
	color_select     Color  // Text selection highlight
	fill             bool
	fill_border      bool
	padding          Padding
	padding_border   Padding
	radius           f32
	text_style       TextStyle
}
```

## Creating Consistent Custom Styles

When creating custom styles, maintain consistency with your theme:

```v
import gui

fn my_styles_from_theme(theme gui.Theme) (gui.ButtonStyle, gui.InputStyle) {
	button_style := gui.ButtonStyle{
		...theme.button_style
		radius: 8 // Consistent radius for all buttons
	}

	input_style := gui.InputStyle{
		...theme.input_style
		radius: 8 // Match button radius
	}

	return button_style, input_style
}
```

## Style Precedence

Styles are applied in this order (last wins):

1. **Default style** - Hardcoded defaults
2. **Theme style** - From active theme (`theme().component_style`)
3. **View override** - Explicitly set on the view

## When to Override Styles

**Use themes** when:
- Styling the entire application consistently
- Switching between light/dark modes
- Maintaining brand consistency

**Use per-view overrides** when:
- A single view needs special styling
- Creating accent buttons (primary, danger, success)
- Highlighting important UI elements
- Prototyping without modifying the theme

## Common Style Patterns

### Primary Button

```oksyntax
gui.button(
	content: [gui.text(text: 'Save')]
	style:   gui.ButtonStyle{
		...gui.theme().button_style
		color_background: gui.rgb(0, 120, 255)  // Blue
		color:            gui.rgb(255, 255, 255)  // White text
	}
)
```

### Danger Button

```oksyntax
gui.button(
	content: [gui.text(text: 'Delete')]
	style:   gui.ButtonStyle{
		...gui.theme().button_style
		color_background: gui.rgb(255, 59, 48)  // Red
		color:            gui.rgb(255, 255, 255)  // White text
	}
)
```

### Borderless Input

```oksyntax
gui.input(
	style: gui.InputStyle{
		...gui.theme().input_style
		fill_border: false  // No border
	}
)
```

### Rounded Panel

```oksyntax
gui.container(
	style: gui.ContainerStyle{
		...gui.theme().container_style
		fill:             true
		color_background: gui.theme().color_panel
		radius:           12  // Extra rounded
	}
	content: [...]
)
```

## Related Topics

- **[Themes](themes.md)** - Theme system and customization
- **[Colors](../api/utility-functions.md)** - Color utilities
- **[Fonts](fonts.md)** - TextStyle properties