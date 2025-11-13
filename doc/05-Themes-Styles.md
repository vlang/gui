# 5 Themes and Styles

### Overview

Gui’s theming system lets you control colors, paddings, radii, spacing,
and text styles across all views. It is highly granular (each view has
its own style), but also ergonomic thanks to `theme_maker`, which
generates a complete `Theme` from a compact `ThemeCfg`.

If you only need a standard look, use the built‑in dark/light themes. If
you need a brand look, define a small set of overrides and let
`theme_maker` fill in the rest.

---

### Quick start: apply a theme

```v
import gui

mut window := gui.window(
	width:  800
	height: 600
	title:  'Theming'
)

// Pick one of the predefined themes
window.set_theme(gui.theme_dark_bordered)
// or: gui.theme_dark, gui.theme_dark_no_padding,
//     gui.theme_light, gui.theme_light_no_padding, gui.theme_light_bordered

window.run()
```

- Access the active theme anywhere using `gui.theme()`.
- Typical usage inside your UI code:

```oksyntax
gui.text(
    text: 'Headline'
    text_style: gui.theme().b2 // built-in bold preset
)

// Use theme colors/sizing for custom drawing
layout.shape.color = gui.theme().color_hover
```

---

### Anatomy: Theme vs ThemeCfg vs Styles

- Theme (in `theme.v`)
  - A fully materialized palette + styles for every view.
  - Includes global colors (`color_background`, `color_panel`,
    `color_interior`, `color_hover`, `color_focus`, `color_active`,
    `color_border`, `color_select`) and flags like `titlebar_dark`.
  - Holds a style struct per view: `button_style`, `input_style`,
    `menubar_style`, `dialog_style`, `progress_bar_style`,
    `scrollbar_style`, `tree_style`, and more.
  - Provides convenience text presets sized like H1–H6: `n1..n6`
    (normal), `b1..b6` (bold), `i1..i6` (italic), `m1..m6` (mono),
    `icon1..icon6` (icon font).
- ThemeCfg (in `theme.v`)
  - A small config used to create a `Theme`. You typically set a name, a
    base color palette, common paddings/radii, and a default
    `text_style`.
  - Most fields have sensible defaults; set only what you need.
- Style structs (in `styles.v`)
  - One struct per view (e.g., `ButtonStyle`, `InputStyle`,
    `DialogStyle`, `MenubarStyle`, …).
  - Each contains the properties that control rendering: colors,
    `fill`/`fill_border`, padding, radius, spacing, and text styles.

---

### Constants you’ll use often

- Radius: `radius_none`, `radius_small`, `radius_medium`,
  `radius_large`, `radius_border`
- Text sizes: `size_text_tiny`, `size_text_x_small`, `size_text_small`,
  `size_text_medium`, `size_text_large`, `size_text_x_large`
- Spacing: `spacing_small`, `spacing_medium`, `spacing_large`, plus
  `text_line_spacing` for extra line height
- Colors: dark/light variants for backgrounds, panels, interiors, hover,
  focus, active, borders, selection, and text
- Scrolling and progress bars: `scroll_multiplier`, `scroll_delta_line`,
  `scroll_delta_page`, `size_progress_bar`

These are surfaced on `Theme` as well (e.g., `theme().spacing_medium`,
`theme().size_text_large`).

---

### Built‑in themes

Predefined configs and instances (all created via `theme_maker`):

- Dark: `theme_dark_cfg`, `theme_dark`, `theme_dark_no_padding_cfg`,
  `theme_dark_no_padding`, `theme_dark_bordered_cfg`,
  `theme_dark_bordered`
- Light: `theme_light_cfg`, `theme_light`, `theme_light_no_padding_cfg`,
  `theme_light_no_padding`, `theme_light_bordered_cfg`,
  `theme_light_bordered`

Pick one as‑is or start from a config and tweak a few fields.

---

### Create your own theme (the recommended way)

Define a `ThemeCfg` with a few overrides, then generate the theme:

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
		text_style:         gui.TextStyle{ // see Fonts doc for details
			...gui.theme_dark_cfg.text_style
			// family: ''  // uncomment to use system font for all text
		}
	})
}
```

Notes

- `theme_maker` keeps container backgrounds transparent by default
  (not filled).
- All fields in `ThemeCfg` have defaults; you can specify just a handful
  and still get a complete, consistent theme.
- You can further tweak the returned theme before applying it:

```oksyntax
mut t := my_brand_theme()
// Round buttons a bit more
mut bs := t.button_style
bs.radius = 10
// Apply the modified button style back
// (structs are values — assign the whole style if needed)
t = gui.Theme{ ...t, button_style: bs }

window.set_theme(t)
```

---

### Per‑view overrides (without creating a new theme)

Most views let you override style or text style directly:

```oksyntax
// Use the current theme for most things, but custom radius for this one button
gui.button(
    text: 'Primary'
    style: gui.ButtonStyle{ ...gui.theme().button_style, radius: 12 }
)

// Change font only for a single text view
// (empty family = platform default system font)
gui.text(
    text: 'Hello, system font!'
    text_style: gui.TextStyle{ ...gui.theme().text_style, family: '' }
)
```

See also: “6 Fonts” for system and custom fonts.

---

### Working with text styles

Use the presets on `Theme` to keep sizes consistent:

- Normal: `n1`..`n6` (e.g., `theme().n2` for a larger headline)
- Bold: `b1`..`b6`
- Italic: `i1`..`i6`
- Mono: `m1`..`m6`
- Icons: `icon1`..`icon6`

Example:

```oksyntax
gui.text(text: 'Section', text_style: gui.theme().b2)

gui.text(
    text: 'Code sample'
    text_style: gui.theme().m4 // monospaced preset
)
```

---

### Runtime access and switching

- Read the active theme: `gui.theme()`.
- Switch themes at runtime via a window:
  `window.set_theme(gui.theme_light)` or pick any custom theme you
  created.
- Typical toggle:

```oksyntax
w.set_theme(if use_light { gui.theme_light } else { gui.theme_dark })
```

---

### Reference: key fields on ThemeCfg

Commonly changed fields (see `theme.v` for the full list):

- Identity: `name`
- Palette: `color_background`, `color_panel`, `color_interior`,
  `color_hover`, `color_focus`, `color_active`, `color_border`,
  `color_border_focus`, `color_select`, `titlebar_dark`
- Sizing: `padding`, `padding_border`, `radius`, `radius_border`
- Text: `text_style` (base style applied throughout, including
  `line_spacing`)
- Shared constants exposed for convenience:
  `padding_small|medium|large`, `radius_small|medium|large`,
  `spacing_small|medium|large`, `size_text_*`, `scroll_*`

---

### Tips and gotchas

- Start from an existing `*_cfg` and change a few fields — this is the
  easiest path.
- Prefer the predefined `*_no_padding` or `*_bordered` variants when you
  only need layout tweaks.
- `spacing_text` on `Theme` is the extra line height added to text; use
  it to fine‑tune dense vs airy layouts.
- Scrolling feel is controlled by `scroll_multiplier`,
  `scroll_delta_line`, `scroll_delta_page` on the theme. Tune them for
  your app’s UX if needed.
- For iconography, use the icon text presets (`icon1..icon6`) or set
  `family: gui.font_file_icon` on a `TextStyle`.

---

### How Themes and Styles work together

- `Theme` aggregates all per‑view style structs from `styles.v`.
- `theme_maker(cfg)` builds a consistent `Theme` from a compact
  `ThemeCfg` by applying your palette/sizing across all views.
- Each view uses its corresponding style struct at render time. Override
  per‑view when needed; otherwise rely on the theme for consistency.