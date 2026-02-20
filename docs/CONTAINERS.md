# Containers

Containers are the building blocks of every v-gui layout. They hold
other views, control how children are arranged, and provide sizing,
alignment, scrolling, and styling options.

All containers share a single configuration struct — `ContainerCfg` —
so every option described below applies to `column`, `row`, `wrap`,
`canvas`, and `circle` alike.

## Container Types

### `column`

Arranges children **top to bottom**. Gaps between items are set with
`spacing`.

```v ignore
gui.column(
    spacing: 8
    content: [
        gui.text(text: 'First'),
        gui.text(text: 'Second'),
        gui.text(text: 'Third'),
    ]
)
```

### `row`

Arranges children **left to right**.

```v ignore
gui.row(
    spacing: 8
    v_align: .middle
    content: [
        gui.text(text: 'Label'),
        gui.button(content: [gui.text(text: 'OK')]),
    ]
)
```

### `wrap`

Arranges children left to right and **flows to the next line** when the
container width is exceeded. Resize the window to see items reflow.
Sugar for `row(wrap: true, ...)`.

```v ignore
gui.wrap(
    sizing:  gui.fill_fit
    spacing: 8
    content: [
        gui.checkbox(label: 'Alpha', ...),
        gui.checkbox(label: 'Beta', ...),
        gui.button(content: [gui.text(text: 'Reset')], ...),
    ]
)
```

See `examples/wrap_panel.v` for a runnable demo.

### `canvas`

Places children with **no automatic layout**. Children are positioned
using their own `x`/`y` fields. Use for free-form or absolutely
positioned content.

```v ignore
gui.canvas(
    width:  400
    height: 300
    sizing: gui.fixed_fixed
    content: [
        gui.row(x: 10, y: 20, ...),
    ]
)
```

### `circle`

A column container rendered with a **circular boundary**. Children are
arranged top to bottom inside the circle.

```v ignore
gui.circle(
    width:   80
    height:  80
    sizing:  gui.fixed_fixed
    content: [gui.text(text: 'OK')]
)
```

## Sizing

Every container has independent width and height sizing modes.

| Mode     | Behavior                                            |
|----------|-----------------------------------------------------|
| `.fit`   | Shrinks to content size                             |
| `.fill`  | Expands/shrinks to fill remaining parent space      |
| `.fixed` | Explicit pixel size; `min` and `max` set to value   |

Combine modes with the `Sizing` struct or use a preset constant:

```v ignore
gui.fit_fit      // shrink-wrap both axes (default)
gui.fill_fit     // fill width, shrink-wrap height
gui.fill_fill    // fill both axes
gui.fixed_fixed  // explicit width and height
gui.fixed_fit    // explicit width, shrink-wrap height
// ... and four more combinations
```

Pass explicit pixel sizes when using `.fixed` or as soft minimums for
`.fit`/`.fill`:

```v ignore
gui.column(
    sizing:     gui.fixed_fit
    width:      300
    min_height: 100
    max_height: 400
    content:    [...]
)
```

## Alignment

`h_align` controls alignment **along** the horizontal axis.
`v_align` controls alignment **along** the vertical axis.

| `h_align`  | Behavior                                      |
|------------|-----------------------------------------------|
| `.start`   | Culture-dependent start (default left)        |
| `.end`     | Culture-dependent end (default right)         |
| `.center`  | Center                                        |
| `.left`    | Always left                                   |
| `.right`   | Always right                                  |

| `v_align`  | Behavior                                      |
|------------|-----------------------------------------------|
| `.top`     | Default                                       |
| `.middle`  | Center                                        |
| `.bottom`  | Bottom                                        |

In a `row`, `v_align` centers each child across the cross axis
(vertically). In a `column`, `h_align` centers each child horizontally.

```v ignore
// Row with items vertically centered
gui.row(v_align: .middle, content: [...])

// Column with items horizontally centered
gui.column(h_align: .center, content: [...])
```

## Padding and Spacing

**Padding** insets the content area on all four sides (order: top,
right, bottom, left — same as CSS).

```v ignore
// Custom padding
gui.column(padding: gui.padding(8, 16, 8, 16), content: [...])

// Uniform padding
gui.column(padding: gui.pad_all(10), content: [...])

// Preset padding constants
gui.column(padding: gui.padding_medium, content: [...])
```

Preset padding constants: `padding_none`, `padding_x_small`,
`padding_small`, `padding_medium`, `padding_large`.

**Spacing** is the gap inserted between consecutive children
(`(n − 1) × spacing`).

```v ignore
gui.column(spacing: 12, content: [...])
```

## Scrolling

Set `id_scroll` to a non-zero value (unique per window) to enable
scrolling. Content that overflows the container bounds is hidden until
scrolled into view.

```v ignore
gui.column(
    id_scroll: 1          // enables scrolling; unique per window
    height:    300
    sizing:    gui.fixed_fit
    content:   [/* many items */]
)
```

Restrict scroll direction with `scroll_mode`:

| `scroll_mode`       | Behavior                   |
|---------------------|----------------------------|
| default             | Both axes                  |
| `.vertical_only`    | Vertical scrolling only    |
| `.horizontal_only`  | Horizontal scrolling only  |

Customize scrollbars with `scrollbar_cfg_x` and `scrollbar_cfg_y`:

```v ignore
gui.column(
    id_scroll:       1
    scrollbar_cfg_y: &gui.ScrollbarCfg{
        overflow: .on_hover   // show scrollbar only when hovering
    }
    content: [...]
)
```

`ScrollbarCfg.overflow` options: `.auto` (default — show when content
overflows), `.hidden` (never show), `.visible` (always show),
`.on_hover` (show when mouse is over the scrollbar region).

## Floating

Floating containers draw **over** sibling content. Used for menus,
dropdowns, and tooltips. The `float_anchor` point on the parent and the
`float_tie_off` point on the float determine placement.

```v ignore
gui.column(
    float:         true
    float_anchor:  .bottom_left   // attach to parent's bottom-left
    float_tie_off: .top_left      // align float's top-left to anchor
    float_offset_y: 4             // pixel offset after placement
    content: [...]
)
```

Nine `FloatAttach` positions are available (top/middle/bottom ×
left/center/right): `.top_left`, `.top_center`, `.top_right`,
`.middle_left`, `.middle_center`, `.middle_right`, `.bottom_left`,
`.bottom_center`, `.bottom_right`.

## Group Box (Titled Border)

Embedding a `title` string places label text in the container's border,
near the top-left corner — the classic "group box" pattern. Set
`title_bg` to match the background so the border appears interrupted.

```v ignore
gui.column(
    title:        'Connection'
    title_bg:     gui.theme().color_background
    color_border: gui.theme().color_border
    size_border:  1
    padding:      gui.padding_medium
    content:      [...]
)
```

## Styling

| Field              | Type        | Effect                                    |
|--------------------|-------------|-------------------------------------------|
| `color`            | `Color`     | Fill color (transparent by default)       |
| `color_border`     | `Color`     | Border color                              |
| `size_border`      | `f32`       | Border thickness in pixels                |
| `radius`           | `f32`       | Corner rounding radius                    |
| `shadow`           | `&BoxShadow`| Drop shadow                               |
| `gradient`         | `&Gradient` | Fill gradient                             |
| `border_gradient`  | `&Gradient` | Border gradient                           |
| `blur_radius`      | `f32`       | Background blur radius                    |
| `opacity`          | `f32`       | 0.0 = transparent, 1.0 = opaque (default) |

## Clipping

Set `clip: true` to hide children that overflow the container bounds.
Scroll containers enable clipping automatically.

```v ignore
gui.row(clip: true, width: 200, content: [...])
```

## Visibility and State

| Field       | Effect                                             |
|-------------|----------------------------------------------------|
| `invisible` | Returns an empty placeholder; excluded from layout |
| `disabled`  | Greys out the container and all descendants        |
| `opacity`   | Renders container and children at reduced opacity  |

## Focus and Keyboard Input

Set `id_focus` to a non-zero value to make the container focusable. The
value sets the tab order. `focus_skip` keeps a container focusable by
click but excludes it from tab navigation.

```v ignore
gui.column(
    id_focus:   1
    on_keydown: fn (l &gui.Layout, mut e gui.Event, mut w gui.Window) {
        // handle keys
    }
    content: [...]
)
```

## Event Handlers

| Field          | Signature                                          |
|----------------|----------------------------------------------------|
| `on_click`     | `fn (&Layout, mut Event, mut Window)`              |
| `on_any_click` | `fn (&Layout, mut Event, mut Window)` (all buttons)|
| `on_char`      | `fn (&Layout, mut Event, mut Window)`              |
| `on_keydown`   | `fn (&Layout, mut Event, mut Window)`              |
| `on_mouse_move`| `fn (&Layout, mut Event, mut Window)`              |
| `on_mouse_up`  | `fn (&Layout, mut Event, mut Window)`              |
| `on_hover`     | `fn (mut Layout, mut Event, mut Window)`           |
| `on_scroll`    | `fn (&Layout, mut Window)`                         |
| `amend_layout` | `fn (mut Layout, mut Window)` (post-layout hook)   |

`on_click` fires on left-click only. `on_any_click` fires on any mouse
button. If `on_any_click` is set it takes precedence over `on_click`.

`amend_layout` runs after all sizes and positions are resolved. Use it
for appearance changes based on final geometry (hover highlights, dynamic
color). Do not change sizes inside this callback.

## Tooltips

Attach a tooltip to any container with the `tooltip` field:

```v ignore
gui.row(
    tooltip: &gui.TooltipCfg{
        id:      'my-tooltip'
        content: [gui.text(text: 'More info')]
    }
    content: [...]
)
```

## Hero Transitions

Set `hero: true` to participate in animated hero transitions between
layout states. Matching `id` values across frames are interpolated.

```v ignore
gui.column(id: 'panel', hero: true, content: [...])
```

## Related Files

- `view_container.v` — `ContainerCfg`, `column`, `row`, `wrap`,
  `canvas`, `circle`
- `sizing.v` — `Sizing`, `SizingType`, preset constants
- `alignment.v` — `Axis`, `HorizontalAlign`, `VerticalAlign`
- `padding.v` — `Padding`, `padding()`, `pad_all()`, `pad_tblr()`
- `layout_wrap.v` — wrap line-breaking algorithm
- `layout_float.v` — `FloatAttach`, floating layout positioning
- `view_scrollbar.v` — `ScrollbarCfg`, `ScrollMode`
- `docs/LAYOUT_ALGORITHM.md` — full layout pipeline reference

## Examples

- `examples/wrap_panel.v` — wrap container with mixed widget types
- `examples/column_scroll.v` — scrollable column with 10,000-item list
