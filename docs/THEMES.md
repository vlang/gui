# Themes

The gui framework includes a complete theming system. Nine semantic
color slots, typography scales, spacing presets, and per-widget
styles are derived from a compact `ThemeCfg` struct via
`theme_maker()`. Themes can be defined in code, loaded from JSON,
switched at runtime, and browsed with a built-in toggle view.

## Built-in Themes

Seven presets are auto-registered at startup:

| Constant                    | Style                        |
|-----------------------------|------------------------------|
| `theme_dark`                | Dark, standard padding       |
| `theme_dark_no_padding`     | Dark, zero padding/borders   |
| `theme_dark_bordered`       | Dark, 1.5 px borders         |
| `theme_light`               | Light, standard padding      |
| `theme_light_no_padding`    | Light, zero padding/borders  |
| `theme_light_bordered`      | Light, 1.5 px borders        |
| `theme_blue_bordered`       | Blue-tinted dark, bordered   |

Apply a preset in `on_init`:

```v ignore
gui.window(gui.WindowCfg{
    on_init: fn (mut w gui.Window) {
        w.set_theme(gui.theme_dark_bordered)
        w.update_view(my_view)
    }
})
```

The default theme is `theme_dark_no_padding`.

## Creating a Custom Theme

Define a `ThemeCfg` with a name and any color overrides, then
pass it to `theme_maker()`:

```v ignore
cfg := gui.ThemeCfg{
    name:             'my-theme'
    color_background: gui.rgb(20, 20, 30)
    color_select:     gui.rgb(100, 150, 255)
    color_hover:      gui.rgb(60, 60, 70)
}
theme := gui.theme_maker(&cfg)
w.set_theme(theme)
```

`theme_maker` fills every widget style, typography scale, and
spacing preset from the nine color slots plus `text_style`,
`padding`, `radius`, and `spacing_*` fields. Only override
what differs from the dark defaults.

### ThemeCfg Fields

| Field              | Type        | Default              |
|--------------------|-------------|----------------------|
| `name`             | `string`    | *required*           |
| `color_background` | `Color`     | dark gray            |
| `color_panel`      | `Color`     | slightly lighter     |
| `color_interior`   | `Color`     | control interior     |
| `color_hover`      | `Color`     | hover highlight      |
| `color_focus`      | `Color`     | keyboard focus       |
| `color_active`     | `Color`     | pressed / active     |
| `color_border`     | `Color`     | border lines         |
| `color_border_focus` | `Color`   | focused border       |
| `color_select`     | `Color`     | accent / selection   |
| `titlebar_dark`    | `bool`      | `false`              |
| `fill`             | `bool`      | `true`               |
| `fill_border`      | `bool`      | `true`               |
| `text_style`       | `TextStyle` | light-on-dark        |
| `padding`          | `Padding`   | `padding_medium`     |
| `radius`           | `f32`       | `radius_medium`      |
| `size_border`      | `f32`       | `0`                  |

Additional sizing fields (`padding_small`, `radius_large`,
`spacing_text`, `size_switch_width`, etc.) have sensible
defaults and rarely need changing.

## Semantic Colors

All widget styles derive from nine color slots:

| Slot               | Purpose                          |
|--------------------|----------------------------------|
| `color_background` | Window / screen background       |
| `color_panel`      | Side panels, grouped controls    |
| `color_interior`   | Interior of buttons and inputs   |
| `color_hover`      | Mouse-hover state                |
| `color_focus`      | Keyboard-focus ring              |
| `color_active`     | Pressed / active indicator       |
| `color_border`     | Border lines                     |
| `color_border_focus` | Border when focused            |
| `color_select`     | Accent: links, selection, caret  |

Text color is stored in `text_style.color`, not as a
separate slot.

## Theme Registry

Themes are stored in a global registry keyed by name.

```v ignore
// Register
gui.theme_register(theme)

// Retrieve by name
theme := gui.theme_get('my-theme')!

// Load every .json theme in a directory
gui.theme_load_dir('/path/to/themes')!
```

### Theme Toggle View

`theme_toggle` renders a palette-icon button that opens a
dropdown listing all registered themes:

```v ignore
w.theme_toggle(gui.ThemeToggleCfg{
    id:       'theme-picker'
    id_focus: 100
    on_select: fn (name string, mut e gui.Event, mut w gui.Window) {
        // optional callback after theme switch
    }
})
```

Arrow keys navigate the list. Selecting an entry calls
`theme_get` then `set_theme` automatically.

## JSON Themes

Themes can be serialized to and from JSON.

```v ignore
// Load from file
theme := gui.theme_load('my-theme.json')!

// Parse from string
theme := gui.theme_parse(json_string)!

// Save to file
gui.theme_save('my-theme.json', theme)!

// Serialize to JSON string
json_str := gui.theme_to_json(cfg)
```

Abridged JSON format:

```json ignore
{
  "name": "my-theme",
  "colors": {
    "background": "#1E1E1E",
    "panel": "#282828",
    "interior": "#2E2E2E",
    "hover": "#363636",
    "focus": "#3E3E3E",
    "active": "#464646",
    "border": "#404040",
    "border_focus": "#4169E1",
    "select": "#4169E1"
  },
  "titlebar_dark": 1,
  "fill": 1,
  "fill_border": 1,
  "text": {
    "color": "#E1E1E1",
    "size": 16.0,
    "family": "Arial"
  },
  "padding": { "top": 10, "right": 10, "bottom": 10, "left": 10 },
  "size_border": 1.5,
  "radius": 5.5,
  "spacing": { "small": 5, "medium": 10, "large": 15, "text": 0 },
  "sizes": {
    "text_tiny": 10, "text_x_small": 12, "text_small": 14,
    "text_medium": 16, "text_large": 20, "text_x_large": 24
  }
}
```

`theme_load_dir` scans a directory for `*.json` files, parses
each with `theme_parse`, and registers the results.

## Modifying Themes at Runtime

`Theme` methods return a new `Theme` — the original is
unchanged.

### Override Colors

```v ignore
custom := theme.with_colors(
    color_select: gui.rgb(255, 100, 50)
    color_hover:  gui.rgb(70, 70, 70)
)
w.set_theme(custom)
```

`ColorOverrides` uses optional fields (`?Color`); only
supplied colors are replaced.

### Override Widget Styles

Each widget type has a `with_*_style` method:

```v ignore
custom := theme.with_button_style(gui.ButtonStyle{ ... })
custom := theme.with_input_style(gui.InputStyle{ ... })
// ... and so on for ~25 widget types
```

### Adjust Font Size

Scale every text size in the theme by a delta, clamped to
`[min, max]`:

```v ignore
larger := theme.adjust_font_size(2.0, 8, 32)!
w.set_theme(larger)
```

## Theme Generator

The showcase (`examples/showcase.v`, component *Theme
Generator*) provides an interactive editor for creating
themes visually.

### Seed-Color + Palette Strategy

The generator works in HSV color space. It extracts hue and
saturation from a **seed color**, then builds all nine
semantic slots at different brightness steps.

**Tint** (0–100 %) controls how much of the seed's saturation
bleeds into surface colors. At 0 % surfaces are pure gray;
at 100 % they carry the full seed hue.

Six **palette strategies** determine the relationship between
the primary hue (surfaces) and accent hue (interactive
states):

| Strategy   | Accent Hue Offset  | Character              |
|------------|--------------------|------------------------|
| Mono       | 0°                 | Single-hue             |
| Complement | 180°               | High contrast          |
| Analogous  | 30°                | Subtle warm/cool shift |
| Triadic    | 120°               | Balanced contrast      |
| Warm       | Forces 0–60° range | Red-yellow palette     |
| Cool       | Forces 180–270°    | Cyan-blue palette      |

Controls: color picker (seed or text color), tint slider,
radius/border numeric inputs, dark/light toggle, palette
strategy radio group, and a JSON export button.

## Key Files

| File                       | Contents                      |
|----------------------------|-------------------------------|
| `theme_types.v`            | `Theme`, `ThemeCfg` structs   |
| `theme.v`                  | `theme_maker`, `with_*` methods, `adjust_font_size` |
| `theme_defaults.v`         | 7 preset definitions          |
| `theme_registry.v`         | Registry: register, get, load_dir |
| `theme_bundle.v`           | JSON I/O: parse, load, save   |
| `view_theme_toggle.v`      | `theme_toggle` dropdown view  |
| `color.v`                  | `Color` struct, constructors  |
| `color_hsv.v`              | HSV conversions, hex parsing  |
| `examples/showcase.v`      | Theme Generator component     |
