# 16 Progress Bar

The progress bar view is used to visualize the progression of an operation.
It can be displayed horizontally or vertically, with an optional percentage
text label.

See also: `examples/progress_bar.v` for a runnable showcase.

## Quick Start

Here's how to create a simple horizontal progress bar:

```v
import gui

struct App {
mut:
	download_progress f32 = 0.65 // 65%
}

mut app := App{}

gui.progress_bar(
	percent: app.download_progress
	width:   200
)
```

## `progress_bar`

This function creates the progress bar view from a `ProgressBarCfg`.

```v
import gui

pub fn progress_bar(cfg gui.ProgressBarCfg) gui.View
```

Internally, it's a container that holds two child views: one for the
colored progress fill and another optional one for the percentage text label.
The orientation can be set to horizontal or vertical.

## `ProgressBarCfg`

This struct configures the `progress_bar` view.

```oksyntax
@[heap]
pub struct ProgressBarCfg {
pub:
	id              string
	text            string
	sizing          Sizing
	text_style      TextStyle = gui_theme.text_style
	color           Color     = gui_theme.progress_bar_style.color
	color_bar       Color     = gui_theme.progress_bar_style.color_bar
	text_background Color     = gui_theme.progress_bar_style.text_background
	text_padding    Padding   = gui_theme.progress_bar_style.text_padding
	width           f32
	height          f32
	min_width       f32
	min_height      f32
	max_width       f32
	max_height      f32
	percent         f32 // 0.0 <= percent <= 1.0
	radius          f32  = gui_theme.progress_bar_style.radius
	text_show       bool = gui_theme.progress_bar_style.text_show
	text_fill       bool = gui_theme.progress_bar_style.text_fill
	disabled        bool
	invisible       bool
	indefinite      bool // TODO: not implemented
	vertical        bool // orientation
}
```

Key fields:
- `percent`: The progress value, from `0.0` (empty) to `1.0` (full).
- `vertical`: If `true`, the bar is oriented vertically. Defaults to
  horizontal.
- `text_show`: If `true`, a percentage label (e.g., "65%") is displayed in
  the center of the bar.
- `color`: The background color of the progress bar track.
- `color_bar`: The color of the progress fill itself.
- `indefinite`: Intended for indeterminate progress bars, but is not yet
  implemented.

## Variations

### Vertical Progress Bar

Set `vertical: true` to change the orientation.

```v
import gui

gui.progress_bar(
	percent:  0.4
	height:   150
	width:    25
	vertical: true
)
```

### With Percentage Text

Set `text_show: true` to display the percentage value.

```v
import gui

gui.progress_bar(
	percent:   0.75
	width:     200
	text_show: true
)
```

### Custom Styling

You can override the default theme colors, radius, and text style.

```v
import gui

gui.progress_bar(
	percent:         0.9
	width:           200
	text_show:       true
	color:           gui.gray
	color_bar:       gui.rgb(0, 120, 215)
	radius:          8
	text_style:      gui.theme().b4
	text_background: gui.color_transparent
)
```

## Inside a Button

Since buttons are containers, a progress bar can be placed inside one to
create a dynamic button.

```v
import gui

gui.button(
	content: [
		gui.text(text: 'Downloading...', min_width: 100),
		gui.progress_bar(width: 100, percent: 0.5),
	]
)
```

## See Also

- `05-Themes-Styles.md` --- Details on colors, padding, and styling.
- `07-Buttons.md` --- How to compose views inside buttons.
- `08-Container-View.md` --- Understanding the underlying container structure.