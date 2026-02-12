# Layout Algorithm Documentation

## Overview

The v-gui layout system is a constraint-based immediate-mode layout
engine inspired by the
[Clay UI library](https://www.youtube.com/watch?v=by9lQvpvMIc&t=1272s).
It uses a multi-pass pipeline to calculate widget positions and sizes.

Each frame, the view tree is converted to a layout tree, the pipeline
runs, and the resulting shapes are sent to the renderer.

## Data Flow

```
View Tree → Layout Tree → Renderer List → GPU Draw Calls
   ↓            ↓              ↓              ↓
Declarative  Calculated    Drawing      Hardware
 Structure   Positions    Commands     Rendering
```

1. **View Tree**: Declarative UI structure
   (`column`, `row`, `button`, etc.)
2. **Layout Tree**: Calculated positions and sizes for each element
3. **Renderer List**: Flat list of draw commands
   (rectangles, text, images)
4. **GPU Draw Calls**: Hardware-accelerated rendering via sokol/vglyph

## Core Concepts

### Axis

Every container has an `Axis` that controls child arrangement:

| Axis              | Description                        |
|-------------------|------------------------------------|
| `.left_to_right`  | Children laid out horizontally     |
| `.top_to_bottom`  | Children laid out vertically       |
| `.none`           | No automatic arrangement           |

### Sizing Modes

Each axis (width/height) uses one of three `SizingType` values:

| Mode      | Description                                     |
|-----------|-------------------------------------------------|
| `.fit`    | Shrink-wrap to content size                     |
| `.fill`   | Grow or shrink to fill remaining parent space   |
| `.fixed`  | Explicit pixel value; min and max set to value  |

The `Sizing` struct pairs a width and height `SizingType`. Nine
predefined constants cover all combinations: `fit_fit`, `fit_fill`,
`fit_fixed`, `fixed_fit`, `fixed_fill`, `fixed_fixed`, `fill_fit`,
`fill_fill`, `fill_fixed`.

### Alignment

| H-Align   | Behavior                                   |
|-----------|--------------------------------------------|
| `.left`   | No offset (default)                        |
| `.center` | Offset by half the remaining space         |
| `.right`  | Offset by all remaining space              |
| `.start`  | Culture-dependent (currently `.left`)      |
| `.end`    | Culture-dependent (currently `.right`)     |

| V-Align   | Behavior                                   |
|-----------|--------------------------------------------|
| `.top`    | No offset (default)                        |
| `.middle` | Offset by half the remaining space         |
| `.bottom` | Offset by all remaining space              |

Alignment is applied in two directions:

- **Along the axis**: shifts all children as a group within the
  container (e.g., centering a row's children horizontally).
- **Across the axis**: shifts each child individually within the
  cross-axis space (e.g., vertically centering each child in a row).

### Padding and Spacing

- **Padding**: insets the container's content area on all four sides.
- **Spacing**: gap inserted between consecutive children
  (fence-post: `(n-1) * spacing`).

### Constraints (min/max)

Each shape can carry `min_width`, `max_width`, `min_height`,
`max_height`. These are enforced after intrinsic sizing and after
fill distribution. When `sizing` is `.fixed`, min and max are both
set equal to the explicit size.

### over_draw

A shape with `over_draw = true` is allowed to draw into its parent's
padding area. It is excluded from spacing calculations and from
content-size measurements, so it does not affect the layout of
siblings. Used for elements like scrollbars that overlay content.

## Layout Pipeline

Before the pipeline runs, two preparation steps execute:

- **Set parents**: walk the tree, set each node's `.parent` pointer.
- **Extract floats**: remove floating layouts from the tree into a
  separate list, replacing them with empty placeholders.

The pipeline then runs on the main layout. Afterward, it runs again
on each extracted floating layout independently.

### Pipeline Steps

| #    | Function                       | Purpose                      |
|------|--------------------------------|------------------------------|
| 1    | `layout_widths`                | Intrinsic widths             |
| 2    | `layout_fill_widths`           | Fill-distribute widths       |
| 3    | `layout_wrap_text`             | Text wrapping                |
| 4    | `layout_heights`               | Intrinsic heights            |
| 5    | `layout_fill_heights`          | Fill-distribute heights      |
| 6    | `layout_adjust_scroll_offsets` | Clamp scroll offsets         |
| 7    | `layout_positions`             | X, Y positioning             |
| 8    | `layout_disables`              | Propagate disabled state     |
| 9    | `layout_scroll_containers`     | Tag text scroll parents      |
| 10   | `layout_amend`                 | Post-layout callbacks        |
| 11a  | `apply_layout_transition`      | Animate layout changes       |
| 11b  | `apply_hero_transition`        | Animate hero elements        |
| 12   | `layout_set_shape_clips`       | Compute clipping rectangles  |
| 13   | `layout_hover`                 | Update hover states          |

### Why Multiple Passes?

Each pass has dependencies on previous passes:

- **Width before height**: text wrapping depends on available width.
- **Intrinsic before fill**: minimum sizes must be known before
  distributing remaining space.
- **Size before position**: elements cannot be positioned without
  knowing their dimensions.
- **Position before clips**: clipping rectangles require final
  positions.
- **Clips before hover**: hit testing needs clipping info.

This separation avoids circular dependencies and keeps each pass
simple.

### Step-by-Step Description

**Step 1 — Intrinsic Widths** (`layout_widths`).
Walk the tree bottom-up. For each container:

- If sizing is `.fixed`, the width is already set; just recurse into
  children.
- If the axis is `.left_to_right` (along-axis): sum all children's
  widths plus spacing plus padding.
- If the axis is `.top_to_bottom` (cross-axis): take the widest
  child plus padding.
- Clamp to min/max constraints.

**Step 2 — Fill-Distribute Widths** (`layout_fill_widths`).
Walk top-down. For each container whose axis is `.left_to_right`:

1. Compute remaining width = container width − padding − spacing
   − sum of children widths.
2. If remaining > 0, grow `.fill` children. If remaining < 0,
   shrink them. (See "Fill Distribution" below.)

For `.top_to_bottom` containers: each `.fill` child gets the
container's content width (minus padding), clamped to min/max.

**Step 3 — Text Wrapping** (`layout_wrap_text`).
Walk the tree. For each text shape, wrap its content to fit the
now-known width. Wrapping changes the shape's minimum height, which
is why this runs between width and height passes.

**Step 4 — Intrinsic Heights** (`layout_heights`).
Same logic as Step 1 but on the vertical axis:

- `.top_to_bottom` (along-axis): sum children heights + spacing +
  padding.
- `.left_to_right` (cross-axis): tallest child + padding.
- Special case: a `.fill`-height scroll container gets a small
  minimum height so it can shrink freely.

**Step 5 — Fill-Distribute Heights** (`layout_fill_heights`).
Same logic as Step 2 but on the vertical axis.

**Step 6 — Adjust Scroll Offsets** (`layout_adjust_scroll_offsets`).
For each scroll container, clamp scroll offsets so they stay within
the valid range (0 to content overflow). This handles cases where
a window resize makes the current offset invalid.

**Step 7 — Positions** (`layout_positions`).
Walk top-down. For each child:

1. Start at parent position + padding.
2. Add scroll offsets if inside a scroll container.
3. Compute along-axis alignment offset (shift the group of children
   if center/right/bottom aligned).
4. Compute cross-axis alignment offset per child (center or align
   each child individually).
5. Recurse, advancing the cursor by child size + spacing.

Floating layouts get their starting position from
`float_attach_layout`, which computes coordinates from the parent's
anchor point and the float's tie-off point, plus any offset.

**Step 8 — Disable Propagation** (`layout_disables`).
Walk the tree. If a parent is disabled, mark all descendants
disabled.

**Step 9 — Scroll Container Tags** (`layout_scroll_containers`).
Walk the tree. For each text shape, record the nearest ancestor
scroll container's `id_scroll`. This allows text selection to
auto-scroll the correct parent.

**Step 10 — Layout Amendments** (`layout_amend`).
Walk bottom-up. Call each shape's `amend_layout` callback if set.
These callbacks can adjust appearance after final positions are
known (e.g., showing hover highlights). They should not change
sizes.

**Step 11a — Layout Transitions** (`apply_layout_transition`).
If a layout transition animation is active, interpolate each
shape's position/size between its previous and current values.

**Step 11b — Hero Transitions** (`apply_hero_transition`).
If a hero transition animation is active, interpolate matching
hero-tagged shapes between their old and new positions.

**Step 12 — Clipping Rectangles** (`layout_set_shape_clips`).
Walk top-down. Each shape's clip rectangle is the intersection of
its own bounds with its parent's clip. This produces the visible
region used for hit testing and draw culling.

**Step 13 — Hover States** (`layout_hover`).
Walk children first (front-to-back priority). For each shape with
an `on_hover` handler: if the mouse is inside the shape's clip
rectangle, call the handler. Stop after the first shape handles
the event.

### Fill Distribution Strategy

The `distribute_space` function handles both growing and shrinking
of `.fill`-sized children. The approach equalizes children
incrementally:

**Growing** (remaining space > 0):

1. Find the smallest `.fill` child and the next-smallest.
2. Grow all smallest children toward the next-smallest size,
   splitting the available space evenly among them.
3. If a child hits its `max_width`/`max_height`, lock it and
   remove it from candidates.
4. Repeat until no space remains or no candidates remain.

**Shrinking** (remaining space < 0):

1. Find the largest child (including `.fixed` siblings as
   reference points) and the next-largest.
2. Shrink all largest `.fill` children toward the next-largest,
   splitting the deficit evenly.
3. If a child hits its `min_width`/`min_height`, lock it and
   remove it from candidates.
4. Repeat until the deficit is resolved or no candidates remain.

This strategy prevents any single child from becoming much larger
or smaller than its siblings, producing visually balanced layouts.

## Floating Layouts

Floating layouts (tooltips, dropdowns, dialogs) are removed from
the main tree before the pipeline runs. Each floater is processed
independently through the full pipeline.

Positioning uses two anchor points:

- **`float_anchor`**: a point on the parent (e.g., `.bottom_left`).
- **`float_tie_off`**: a point on the float itself
  (e.g., `.top_left`).

The float is placed so that its tie-off point coincides with the
parent's anchor point, then shifted by `float_offset_x/y`.
Nine anchor positions are available via the `FloatAttach` enum
(combinations of top/middle/bottom × left/center/right).

Floating layouts render after the main layout, so they appear on
top. Dialogs are added last to ensure they are always topmost.

## Scroll Containers

A container becomes scrollable by setting `id_scroll` to a nonzero
value. Scroll state is stored in the window's `ViewState`:

- `scroll_x[id_scroll]` — horizontal offset
- `scroll_y[id_scroll]` — vertical offset

The scroll offset shifts child positions (Step 7) but does not
change the container's own size. Step 6 clamps offsets to prevent
scrolling past content bounds. Scroll containers automatically
enable clipping so children outside the viewport are not drawn.

## Layout Amendments

The `amend_layout` callback on a shape runs in Step 10, after all
positions and sizes are final. It receives the layout and window,
and can modify appearance properties (color, visibility,
decorations). It should not change sizes, as the size passes have
already completed.

Common uses: hover highlights, dynamic styling based on position,
tooltip placement adjustments.

## Related Files

- `layout.v` — `layout_arrange`, `layout_pipeline`,
  parent/float extraction
- `layout_sizing.v` — `layout_widths`, `layout_heights`,
  `layout_fill_widths`, `layout_fill_heights`, `distribute_space`
- `layout_position.v` — `layout_positions`, `layout_disables`,
  `layout_scroll_containers`, `layout_amend`, `layout_hover`,
  `layout_set_shape_clips`, `layout_wrap_text`,
  `layout_adjust_scroll_offsets`
- `layout_float.v` — `FloatAttach`, `float_attach_layout`
- `layout_query.v` — `spacing()`, `content_width`,
  `content_height`, query helpers
- `sizing.v` — `SizingType`, `Sizing`, constants
- `alignment.v` — `Axis`, `HorizontalAlign`, `VerticalAlign`
- `animation_layout.v` — `apply_layout_transition`
- `animation_hero.v` — `apply_hero_transition`
