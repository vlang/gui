----------------------
# 4 Rows and Columns 
----------------------

Rows and columns are the two fundamental layout containers in Gui. -
Rows lay out their children horizontally (left-to-right in LTR
locales). - Columns lay out their children vertically (top-to-bottom).

Everything you see in the predefined views (commonly called widgets) is
composed from these two containers. In other words, most widgets are
just compositions of rows, columns, and a few primitives like `text` and
`image`.

## Example: a button is just rows

Below is the essential structure of the built-in `button` view. It’s two
nested rows: an outer row that draws the border/background and an inner
row that holds the content.

``` v
pub fn button(cfg ButtonCfg) View {
	return row(
		id:           cfg.id
		id_focus:     cfg.id_focus
		color:        cfg.color_border
		padding:      cfg.padding_border
		fill:         cfg.fill_border
		radius:       cfg.radius_border
		width:        cfg.width
		height:       cfg.height
		disabled:     cfg.disabled
		invisible:    cfg.invisible
		min_width:    cfg.min_width
		max_width:    cfg.max_width
		min_height:   cfg.min_height
		max_height:   cfg.max_height
		sizing:       cfg.sizing
		cfg:          &cfg
		on_click:     cfg.on_click
		on_char:      cfg.on_char_button
		amend_layout: cfg.amend_layout
		content:      [
			row(
				sizing:  fill_fill
				h_align: cfg.h_align
				v_align: cfg.v_align
				padding: cfg.padding
				radius:  cfg.radius
				fill:    cfg.fill
				color:   cfg.color
				content: cfg.content
			),
		]
	)
}
```

The takeaway: there is nothing magic about `button`. If you need a
different look or behavior, build your own composition out of rows and
columns.

## What rows and columns can do

Rows and columns have many capabilities. A quick tour:

- Focusable — can receive keyboard focus so you can style them based on
  focus state.
- Scrollable — content can scroll when it doesn’t fit.
- Floatable — can render on top of other content (useful for menus,
  tooltips, popovers).
- Sizing — fill, fit, and fixed sizing options (see `sizing`).
- Alignment — horizontal and vertical alignment of child content.
- Styling — outline color, filled backgrounds, corner radii.
- Group text — optional text embedded in the border (group box style).

### Focus and styling

“Focus” means the row/column can be the target of keyboard input. While
you typically don’t type directly into a container, focus is valuable
for styling: borders, fills, or text color can change when the container
is focused. Use this to indicate selection, active panels, and keyboard
navigation targets.

### Scrolling

Enable scrolling by setting the `id_scroll` to a non-zero value. Content
that extends past the boundaries of the row (or column) is hidden until
scrolled into view.

Scrollbars are optional and configurable: - Show vertical and/or
horizontal bars. - Hide them entirely when content fits. - Auto-show on
hover over the scrollbar region. - Place them floating over content or
beside content, as desired. - Restrict scrolling to vertical-only or
horizontal-only via `scroll_mode`.

### Floating content

Floating is powerful because it allows a view to draw over other
content. Menus are a good example: submenus are columns that float below
or next to their parent item. The drawing is straightforward; the
complexity is primarily in the mouse/keyboard handling.

### Alignment

Content can be aligned start, center, and end. “Start” and “end” map to
left/right in left-to-right locales and flip in right-to-left locales.
Columns additionally align content top, middle, and bottom. Use
`h_align` and `v_align` on the container that owns the children you want
to align.

### Color, fill, and outline

Rows and columns are transparent by default. Set `color` to draw an
outline. Set `fill: true` to fill the interior with that color. Combine
with `padding` to create borders, chips, and panels.

### Corner radius

Corners can be square or rounded. Control roundness with the `radius`
property.

### Group boxes (embedded text)

To draw text embedded in the container’s outline (near the top-left),
set the `text` property. This is commonly used for group boxes.

## Small recipes

- Padded horizontal row with centered content

``` v
row(
    padding: 8
    h_align: center
    v_align: middle
    content: [
        /* your views here */
    ]
)
```

- Scrollable column (vertical-only)

``` v
column(
    id_scroll: 1         // any non-zero id enables scrolling
    // scroll_mode: ...  // restrict direction if desired
    content: [
        /* many items */
    ]
)
```

- Floating menu panel (conceptual)

``` v
column(
    // float: true       // depending on your composition
    padding: 4
    radius: 4
    fill: true
    content: [ /* menu items */ ]
)
```

## See also

- 03-Views.md — how views are composed
- 05-Themes-Styles.md — colors, borders, radii, and theme variables
- 07-Buttons.md — more on buttons built from rows

Beyond `text` and `image`, the predefined views are compositions of rows
and columns. It’s rectangles within rectangles all the way down!
