---------------------
# 5 Themes and Styles
---------------------

### Overview

The `theme.v` file defines the theming system for the GUI framework. It
provides constants for sizing, spacing, and colors, as well as
structures and functions to create and manage themes. The system is
designed to be highly customizable, allowing each view to have its own
styles, but also provides helpers to make defining new themes easy and
consistent.

------------------------------------------------------------------------

### Key Components

#### Constants

- **Radius**: `radius_none`, `radius_small`, `radius_medium`,
  `radius_large`, `radius_border`
- **Text Sizes**: `size_text_tiny`, `size_text_x_small`,
  `size_text_small`, `size_text_medium`, `size_text_large`,
  `size_text_x_large`
- **Spacing**: `spacing_small`, `spacing_medium`, `spacing_large`,
  `text_line_spacing`
- **Colors**: Sets of dark and light colors for backgrounds, panels,
  interiors, hovers, focus, active, borders, selection, and text.
- **Scroll and Progress Bar**: `scroll_multiplier`, `scroll_delta_line`,
  `scroll_delta_page`, `size_progress_bar`

#### Structures

- **Theme**
  - Describes a complete theme, including all colors, styles, paddings,
    radii, spacings, and text styles for every view component.
  - Contains convenience text styles (`n1`-`n6`, `b1`-`b6`, `i1`-`i6`,
    `m1`-`m6`, `icon1`-`icon6`) for normal, bold, italic, mono, and icon
    fonts at various sizes.
  - Example fields:
    - `color_background`, `color_panel`, `color_interior`,
      `color_hover`, `color_focus`, `color_active`, `color_border`,
      `color_select`, `color_text`
    - Styles for each view: `button_style`, `container_style`,
      `dialog_style`, etc.
    - Sizing and spacing: `padding_small`, `radius_medium`,
      `spacing_large`, etc.
- **ThemeCfg**
  - A configuration struct for creating new themes with sensible
    defaults.
  - Used with `theme_maker` to generate a full `Theme` from a small set
    of overrides.
  - Example fields: `name`, `color_background`, `color_panel`,
    `color_interior`, `color_hover`, `color_focus`, `color_active`,
    `color_border`, `color_select`, `text_style`, `padding`, `radius`,
    etc.

#### Theme Variants

- **Predefined Theme Configs and Instances**
  - `theme_dark_cfg`, `theme_dark`, `theme_dark_no_padding_cfg`,
    `theme_dark_no_padding`, `theme_dark_bordered_cfg`,
    `theme_dark_bordered`
  - `theme_light_cfg`, `theme_light`, `theme_light_no_padding_cfg`,
    `theme_light_no_padding`, `theme_light_bordered_cfg`,
    `theme_light_bordered`
  - Each variant is created using `theme_maker` and a corresponding
    `ThemeCfg`.

#### Functions

- **theme_maker(cfg &ThemeCfg) Theme**
  - Generates a complete `Theme` from a `ThemeCfg`.
  - Applies the configuration to all view styles, text styles, paddings,
    radii, and spacings.
  - Ensures consistency and reduces boilerplate when defining new
    themes.
- **theme() Theme**
  - Returns the current global theme.

------------------------------------------------------------------------

### Usage Example

To define a new theme, create a `ThemeCfg` with your desired overrides
and pass it to `theme_maker`:

``` v
pub const my_theme_cfg = ThemeCfg{
    name: 'my-theme'
    color_background: rgb(30, 30, 30)
    // ...other overrides...
}
pub const my_theme = theme_maker(my_theme_cfg)
```

------------------------------------------------------------------------

### Notes

- The theming system is granular, but you can use `theme_maker` to avoid
  repetitive code.
- All styles (button, input, menubar, etc.) can be customized per theme.
- Predefined themes (`dark`, `light`, and their variants) are available
  for immediate use or as templates.

------------------------------------------------------------------------

## Style Structs

### Overview

Defines the individual style structs for each GUI component. Each struct
contains all the visual properties needed to render that component, such
as colors, padding, radii, and text styles.

------------------------------------------------------------------------

## How They Work Together

- The `Theme` struct (from `theme.v`) aggregates all the style structs
  (from `styles.v`) for each component.
- You can create a new theme by configuring a `ThemeCfg` and passing it
  to `theme_maker`, which will generate all the style structs with your
  chosen palette and sizing.
- Each component in the GUI uses its corresponding style struct for
  rendering.
