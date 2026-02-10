# Splitter

`splitter` provides two resizable panes separated by a draggable divider.

Core behavior:
- Horizontal (`left/right`) or vertical (`top/bottom`) orientation
- Real-time drag resize
- Per-pane min/max size constraints
- Pane collapse/expand for first or second pane
- Keyboard resize/collapse support
- Nested splitters by composition
- Theme-driven styling for divider, grip, and collapse buttons

## Quick Start

```v ignore
import gui

@[heap]
struct App {
pub mut:
	main_split gui.SplitterState = gui.SplitterState{
		ratio: 0.30
	}
}

fn main_view(window &gui.Window) gui.View {
	app := window.state[App]()
	return gui.splitter(
		id:        'main_split'
		id_focus:  31
		ratio:     app.main_split.ratio
		collapsed: app.main_split.collapsed
		on_change: fn (ratio f32, collapsed gui.SplitterCollapsed, mut _e gui.Event, mut w gui.Window) {
			w.state[App]().main_split = gui.splitter_state_normalize(gui.SplitterState{
				ratio:     ratio
				collapsed: collapsed
			})
		}
		first: gui.SplitterPaneCfg{
			min_size: 140
			content:  [left_panel()]
		}
		second: gui.SplitterPaneCfg{
			min_size: 220
			content:  [right_panel()]
		}
	)
}
```

`splitter` is controlled: app state owns `ratio` and `collapsed`.

## API Summary

`SplitterCfg` main fields:
- `id string` (required)
- `id_focus u32` keyboard focus id
- `orientation SplitterOrientation` (`.horizontal` default, `.vertical`)
- `ratio f32` split ratio (`0..1`)
- `collapsed SplitterCollapsed` (`.none`, `.first`, `.second`)
- `on_change fn (f32, SplitterCollapsed, mut Event, mut Window)` (required)
- `first SplitterPaneCfg` / `second SplitterPaneCfg` (required)
- `handle_size f32`
- `drag_step f32` / `drag_step_large f32`
- `double_click_collapse bool`
- `show_collapse_buttons bool`
- style fields (`color_*`, `size_border`, `radius`, `radius_border`)

`SplitterPaneCfg` fields:
- `min_size f32`
- `max_size f32` (`0` means no max)
- `collapsible bool` (`true` default)
- `collapsed_size f32`
- `content []View`

## Keyboard Behavior

When splitter has focus:
- `Left/Right` resize horizontal splitter
- `Up/Down` resize vertical splitter
- `Shift + Arrow` use `drag_step_large`
- `Home` collapse first pane
- `End` collapse second pane
- `Enter` or `Space` toggle collapse target

## Collapse Rules

- `collapsed: .none` means normal ratio-based split.
- `collapsed: .first` collapses first pane to `first.collapsed_size`.
- `collapsed: .second` collapses second pane to `second.collapsed_size`.
- Only one pane can be collapsed at a time.
- If a pane is not collapsible, requests to collapse it are ignored.

## Constraints

For non-collapsed state, pane sizes are clamped by:
- `first.min_size` / `first.max_size`
- `second.min_size` / `second.max_size`

If constraints conflict, splitter clamps to the nearest feasible size.

## Persistence Pattern

Persistence is app-owned:
1. Keep `SplitterState` in application state.
2. Update it in `on_change`.
3. Save/load that state in app settings for cross-session restore.

Helpers:
- `SplitterState { ratio, collapsed }`
- `splitter_state_normalize(...)`

## Nested Splitters

Place a splitter inside a pane of another splitter:

```v ignore
gui.splitter(
	id: 'outer'
	// ...
	second: gui.SplitterPaneCfg{
		content: [
			gui.splitter(
				id:          'inner'
				orientation: .vertical
				// ...
			),
		]
	}
)
```

## Styling

Theme support:
- `Theme.splitter_style`
- `Theme.with_splitter_style(style)`

Example:

```v ignore
mut style := gui.theme().splitter_style
style = gui.SplitterStyle{
	...style
	handle_size:         12
	color_handle:        gui.rgb(70, 70, 78)
	color_handle_hover:  gui.rgb(90, 90, 102)
	color_handle_active: gui.rgb(110, 110, 128)
}
window.set_theme(gui.theme().with_splitter_style(style))
```
