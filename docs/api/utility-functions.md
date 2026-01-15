# Utility Functions

Helper functions for colors, padding, and common operations.

## Color Functions

### rgb()

Create RGB color:

```v
import gui

color := gui.rgb(255, 100, 0) // Orange
```

Parameters: `(r int, g int, b int) Color`

### rgba()

Create RGBA color with alpha:

```v
import gui

color := gui.rgba(255, 100, 0, 128) // Semi-transparent orange
```

Parameters: `(r int, g int, b int, a int) Color`

### hex()

Create color from hex value:

```v
import gui

color := gui.hex(0xFF6400) // Orange
```

Parameters: `(value int) Color`

## Padding Functions

### Padding struct

```v
pub struct Padding {
pub:
	top    f32
	right  f32
	bottom f32
	left   f32
}
```

### Padding constants

```v
gui.padding_none
// {0, 0, 0, 0}
gui.padding_one
// {1, 1, 1, 1}
gui.padding_two
// {2, 2, 2, 2}
gui.padding_small
// {5, 5, 5, 5}
gui.padding_medium
// {10, 10, 10, 10}
gui.padding_large
// {15, 15, 15, 15}
```

## Sizing Constants

```v
// Width x Height sizing combinations
gui.fit_fit
// Fit both
gui.fit_fill
// Fit width, fill height
gui.fit_fixed
// Fit width, fixed height
gui.fixed_fit
// Fixed width, fit height
gui.fixed_fill
// Fixed width, fill height
gui.fixed_fixed
// Fixed both
gui.fill_fit
// Fill width, fit height
gui.fill_fill
// Fill both
gui.fill_fixed
// Fill width, fixed height
```

## Radius Constants

```v
gui.radius_none
// 0
gui.radius_small
// 4
gui.radius_medium
// 8
gui.radius_large
// 12
gui.radius_border
// 1
```

## Spacing Constants

```v
gui.spacing_small
// 5
gui.spacing_medium
// 10
gui.spacing_large
// 15
```

## Icon Constants

Access embedded Feather Icons:

```v
gui.icon_check
gui.icon_x
gui.icon_chevron_right
gui.icon_chevron_left
gui.icon_menu
gui.icon_settings
gui.icon_save
gui.icon_copy
gui.icon_trash
// ...and many more
```

See [Fonts guide](../core/fonts.md#icon-fonts) for complete icon list.

## Theme Access

### theme()

Get current theme:

```v
current_theme := gui.theme()
```

Returns the active `Theme` struct.

### theme_maker()

Create custom theme from config:

```v
import gui

my_theme := gui.theme_maker(gui.ThemeCfg{
	name:             'custom'
	color_background: gui.rgb(28, 28, 30)
	// ...other config
})
```

See [Themes](../core/themes.md) for details.

## Related Topics

- **[Themes](../core/themes.md)** - Theme system
- **[Sizing](../core/sizing-alignment.md)** - Sizing modes
- **[Fonts](../core/fonts.md)** - Icon fonts