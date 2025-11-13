# 14 List Box

A list box is a view that displays a scrollable list of items, allowing
users to select one or multiple options. It's a convenient composition
of `column` and `row` views, pre-configured to handle selection, hover
states, and subheadings.

- Widget: `list_box`
- Config: `ListBoxCfg`
- Data: `ListBoxOption`
- Callback: `on_select([]string, mut Event, mut Window)`

## Quick Start

Here's how to create a simple list box with a few options:

```v
import gui

struct App {
mut:
	selected_city string
}

mut app := App{}

gui.list_box(
	id:        'cities_list'
	selected:  [app.selected_city]
	data:      [
		gui.list_box_option('New York', 'ny'),
		gui.list_box_option('Detroit', 'dtw'),
		gui.list_box_option('Chicago', 'chi'),
	]
	on_select: fn (values []string, mut _ gui.Event, mut w gui.Window) {
		mut app := w.state[App]()
		if values.len > 0 {
			app.selected_city = values[0]
		}
	}
)
```

## `list_box`

This function creates the list box view. It is a specialized container
that renders a list of `ListBoxOption` items and manages their selection
state.

```oksyntax
pub fn list_box(cfg gui.ListBoxCfg) gui.View
```

Internally, it's a `column` with a border, containing another scrollable
`column` that holds a `row` for each item.

## `ListBoxCfg`

This struct configures the `list_box` view.

```oksyntax
pub struct ListBoxCfg {
pub:
	id               string
	sizing           Sizing
	text_style       TextStyle = gui_theme.list_box_style.text_style
	subheading_style TextStyle = gui_theme.list_box_style.subheading_style
	color            Color     = gui_theme.list_box_style.color
	color_hover      Color     = gui_theme.list_box_style.color_hover
	color_border     Color     = gui_theme.list_box_style.color_border
	color_select     Color     = gui_theme.list_box_style.color_select
	padding          Padding   = gui_theme.list_box_style.padding
	padding_border   Padding   = gui_theme.list_box_style.padding_border
	selected         []string // list of selected values. Not names
	data             []ListBoxOption
	on_select        fn (value []string, mut e Event, mut w Window) = unsafe { nil }
	width            f32
	height           f32
	min_width        f32
	max_width        f32
	min_height       f32
	max_height       f32
	radius           f32 = gui_theme.list_box_style.radius
	radius_border    f32 = gui_theme.list_box_style.radius_border
	id_scroll        u32
	multiple         bool // allow multiple selections
	fill             bool = gui_theme.list_box_style.fill
	fill_border      bool = gui_theme.list_box_style.fill_border
}
```

Key fields: - `data`: An array of `ListBoxOption` structs that define
the items in the list.

- `selected`: An array of strings holding the `value` of each selected item.
- `on_select`: The callback triggered
  when an item is clicked. It receives an array of the currently selected
  values.
- `multiple`: If `true`, allows selecting more than one item.
- `id_scroll`: A non-zero value makes the list box scrollable if its
  content exceeds its height.
- `subheading_style`: A separate `TextStyle` for items that are subheadings.

## `ListBoxOption`

This struct defines a single item in the list. Use the `list_box_option`
helper for concise creation.

```v
pub struct ListBoxOption {
pub:
	name  string
	value string
}

pub fn list_box_option(name string, value string) ListBoxOption
```

### Subheadings

If an option's `name` starts with `---`, it is rendered as a
non-selectable subheading. The three leading hyphens are removed, and
the rest of the name is displayed using the `subheading_style`. A
horizontal line is drawn below it.

```oksyntax
gui.list_box_option('---Category 1', '') // The value is ignored
```

## Interaction and Events

- **Click**: Clicking an item triggers the `on_select` callback. The
  callback receives a new array of selected values. If `multiple` is
  `false`, the new selection replaces the old one. If `true`, the
  clicked item is toggled in the selection.
- **Hover**: Hovering over a selectable item changes its background to
  `color_hover` and the cursor to a pointing hand.
- **Selection**: Selected items are highlighted with the `color_select`
  background color.

## Styling

The list box's appearance is controlled by `gui_theme.list_box_style`
and can be overridden in `ListBoxCfg`.

- The outer container is styled with `color_border`, `padding_border`,
  and `radius_border`.
- The inner container uses `color`, `padding`, and `radius`.
- Selected items use `color_select`.
- Text uses `text_style`, and subheadings use `subheading_style`.

## Multiple Selections

To allow users to select multiple items, set `multiple: true`. The
`on_select` callback will receive an array containing all selected
values.

```v
import gui

struct App {
mut:
	selected_items []string
}

mut app := App{}
gui.list_box(
	multiple:  true
	selected:  app.selected_items // e.g., ['ny', 'chi']
	on_select: fn (values []string, mut _ gui.Event, mut w gui.Window) {
		mut app := w.state[App]()
		app.selected_items = values
	}
	// ...
)
```

## See Also

- `08-Container-View.md` --- Understanding the underlying `column` and
  `row` views.
- `05-Themes-Styles.md` --- Details on colors, padding, and styling.
- `view_select.v` --- For a compact, drop-down selection menu.