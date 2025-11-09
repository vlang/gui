  ------------------------------
  # 8 Container View & Config
  ------------------------------

`view_container.v` defines the fundamental container type used
throughout Gui. Most built‑in views are compositions of these
containers.

This document explains:

- What `ContainerView` is and how it's created
- The `ContainerCfg` configuration and its options
- Predefined helpers: `row`, `column`, `canvas`, `circle`
- Scrolling and scrollbars
- Floating, overlays, and tooltips
- Alignment, sizing, padding, radius, and colors
- Event hooks and layout amendment
- Practical examples

See also: 

- 03-Views.md --- how views are composed 
- 04-Rows-Columns.md --- a practical tour of rows/columns 
- 05-Themes-Styles.md --- color, radius, padding defaults

## Overview

`ContainerView` is the core rectangular (or circular) visual element
that:

- Owns a list of child `View`s (`content`)
- Lays them out horizontally (row) or vertically (column) depending on
  its `axis`
- Can also act as a freeform `canvas` (no auto‑layout) when
  `axis: .none`
- Can draw an outline and/or a filled background
- Supports rounded corners and embedded group text
- Can scroll its content and show scrollbars
- Can float above other content (overdraw) --- useful for menus,
  tooltips, popups

You normally don't instantiate `ContainerView` directly; instead you use
the helper functions that build a configured container:

- `row(cfg ContainerCfg) View` --- lays out children left‑to‑right
- `column(cfg ContainerCfg) View` --- lays out children top‑to‑bottom
- `canvas(cfg ContainerCfg) View` --- no child layout; you position/draw
  manually
- `circle(cfg ContainerCfg) View` --- like `container` but draws a
  circular shape

These helpers accept a `ContainerCfg` which is the single place to set
all options.

## ContainerCfg

The primary options you'll use most often:

- `content []View` --- child views
- `sizing Sizing` --- choose from `fill_*`, `fit_*`, or fixed via
  width/height
- `padding Padding` --- inner spacing; see 05-Themes-Styles.md
- `spacing f32` --- gap between children (for row/column)
- `h_align HorizontalAlign`, `v_align VerticalAlign` --- alignment of
  children
- `color Color`, `fill bool`, `radius f32` --- outline/fill/radius
- `text string` --- optional embedded text (group box style)
- `id_focus u32` --- enables focus tracking/styling for the container
- `disabled bool`, `invisible bool`, `clip bool`, `focus_skip bool`

Scrolling related:

- `id_scroll u32` --- non‑zero enables scroll tracking for this container
- `scroll_mode ScrollMode` --- limit to horizontal‑only or vertical‑only if desired
- `scrollbar_cfg_x &ScrollbarCfg` --- customize the horizontal bar (or hide)
- `scrollbar_cfg_y &ScrollbarCfg` --- customize the vertical bar (or hide)

Floating/overlay related:

- `float bool` --- allow drawing over other content
- `float_anchor FloatAttach`, `float_tie_off FloatAttach` --- positioning aids
- `float_offset_x f32`, `float_offset_y f32` --- manual offset when floating

Events and hooks:

- `on_click fn(&Layout, mut Event, mut Window)` --- mouse click
- `on_any_click fn(&Layout, mut Event, mut Window)` --- catch any button click
- `on_mouse_move`, `on_mouse_up`, `on_keydown`, `on_char`
- `on_hover fn(mut Layout, mut Event, mut Window)` --- hover‑time callback
- `amend_layout fn(mut Layout, mut Window)` --- mutate the computed layout just 
   before rendering children

Tips:

- To hide the container from layout spacing but keep it drawing, use
  `over_draw` on the view side (primarily internal; `invisible` also
  removes spacing by returning a minimal placeholder).

## Predefined constructors

- `row(cfg)`: axis is set to `.left_to_right`. Children are spaced by
  `spacing`.
- `column(cfg)`: axis is set to `.top_to_bottom`. Children are spaced by
  `spacing`.
- `canvas(cfg)`: axis is `.none`; the container won't lay out children.
- `circle(cfg)`: same behavior as `row/column/canvas` based on
  `cfg.axis`, but the shape is circular. Useful for avatars, badges,
  knobs.

Each helper ensures that the inner config pointer (`cfg.cfg`) is
initialized so callbacks can receive your original `ContainerCfg` or
outer struct when needed.

## Scrolling and scrollbars

Set `id_scroll` to any non‑zero value to enable scrolling. When enabled,
scrollbars may be added automatically unless you explicitly hide them
via the corresponding `ScrollbarCfg` with `overflow: .hidden`.

- Horizontal bar: `scrollbar_cfg_x` (orientation is set internally)
- Vertical bar: `scrollbar_cfg_y`
- Auto‑hide or show‑on‑hover are available via `ScrollbarCfg` fields
- Restrict scroll direction via `scroll_mode`

Example: vertical‑only scrolling column with auto scrollbar behavior

``` v
column(
    id:        'files'
    id_scroll: 1
    scroll_mode: .vertical_only
    // scrollbar_cfg_y: &ScrollbarCfg{ overflow: .auto }
    content: [ /* many rows */ ]
)
```

## Floating, overlays, and tooltips

Set `float: true` to allow the container to render over other content.
Use `float_anchor`, `float_tie_off`, and offsets to position. This is
how menus and popovers are composed.

Tooltips integrate with containers via `tooltip &TooltipCfg`. When
present, the container wires an internal mouse‑move shape handler so the
tooltip region follows the container's shape.

``` v
row(
    text: 'Hover me'
    tooltip: &TooltipCfg{
        content: [ text('Helpful tip') ]
    }
    content: [ /* ... */ ]
)
```

## Alignment, sizing, padding, and radius

- Alignment applies to how children are placed inside the container's
  inner rect (after `padding`).
- `sizing` controls how the container itself consumes space within its parent.
- `radius` controls corner rounding; for `circle(...)` a circular `ShapeType` is used.
- Set `fill: true` to fill with `color`; otherwise only the outline is drawn.

See 04-Rows-Columns.md for more alignment recipes.

## Event hooks and layout amendment

Attach event handlers directly on the container. Common patterns:

``` v
row(
    id: 'row-with-events'
    on_click: fn (_ &Layout, mut e Event, mut w Window) {
        if e.mouse_button == .left { /* ... */ }
    }
    on_keydown: fn (_ &Layout, mut e Event, mut w Window) { /* ... */ }
    amend_layout: fn (mut l Layout, mut w Window) {
        // last‑second layout adjustments before children are laid out
        // e.g., dynamically change padding or color based on state
    }
    content: [ /* ... */ ]
)
```

## Practical examples

Centered row with padding and rounded fill:

``` v
row(
    padding: 8
    radius: 6
    fill: true
    color: rgb(240, 240, 240)
    h_align: center
    v_align: middle
    content: [ text('Hello') ]
)
```

Two‑column layout with spacing and scroll:

``` v
row(
    spacing: 12
    content: [
        column(
            id: 'left'
            width: 240
            spacing: 6
            content: [ /* nav items */ ]
        ),
        column(
            id: 'right'
            id_scroll: 42
            scroll_mode: .vertical_only
            content: [ /* long article */ ]
        ),
    ]
)
```

Circular badge:

``` v
circle(
    width: 36
    height: 36
    fill: true
    color: rgb(52, 120, 246)
    content: [
        row(h_align: center, v_align: middle, sizing: fill_fill, content: [ text('9') ])
    ]
)
```

## Notes

- `invisible: true` returns a minimal placeholder that doesn't affect spacing.
- When `clip: true`, children are clipped to the container's inner rect.
- `over_draw` is managed internally for some cases (e.g., invisible spacers or floating scrollbars).

## Related source

- `view_container.v` --- `ContainerView`, `ContainerCfg`,
  `row/column/canvas/circle`
- `view_scrollbar.v` --- scrollbar view
- `view_tooltip.v` --- tooltip view
- `layout.v` --- layout engine
