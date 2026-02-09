# Layout Algorithm Documentation

## Overview

The v-gui layout system is a constraint-based immediate-mode layout engine inspired by the
[Clay UI library](https://www.youtube.com/watch?v=by9lQvpvMIc&t=1272s). It uses a 
multi-pass approach to calculate widget positions and sizes.

## Data Flow

```
View Tree → Layout Tree → Renderer List → GPU Draw Calls
   ↓            ↓              ↓              ↓
Declarative  Calculated    Drawing      Hardware
 Structure   Positions    Commands     Rendering
```

1. **View Tree**: User-defined declarative UI structure (`column`, `row`, `button`, etc.)
2. **Layout Tree**: Calculated positions and sizes for each element
3. **Renderer List**: Flat list of draw commands (rectangles, text, images)
4. **GPU Draw Calls**: Hardware-accelerated rendering via sokol/gg

## Layout Pipeline

The layout pipeline consists of 10 sequential passes, each handling a specific aspect of layout
calculation:

```
┌─────────────────────────────────────────────────────────────┐
│                    LAYOUT PIPELINE                          │
├─────────────────────────────────────────────────────────────┤
│  1. layout_widths()         - Calculate intrinsic widths    │
│  2. layout_fill_widths()    - Expand widths to fill space   │
│  3. layout_wrap_text()      - Wrap text, may affect height  │
│  4. layout_heights()        - Calculate intrinsic heights   │
│  5. layout_fill_heights()   - Expand heights to fill space  │
│  6. layout_adjust_scroll()  - Adjust scroll offsets         │
│  7. layout_positions()      - Calculate X, Y positions      │
│  8. layout_disables()       - Handle disabled states        │
│  9. layout_scroll_containers() - Scroll container logic     │
│ 10. layout_amendments()     - Final adjustments             │
└─────────────────────────────────────────────────────────────┘
```

### Why Multiple Passes?

Each pass has dependencies on previous passes:
- **Width before height**: Text wrapping depends on available width
- **Intrinsic before fill**: Must know minimum sizes before expanding
- **Size before position**: Can't position without knowing dimensions

This separation simplifies the constraint solving and avoids circular dependencies.

## Sizing Modes

Each axis (width/height) can use different sizing modes:

| Mode           | Description            | Example            |
|----------------|------------------------|--------------------|
| **Fixed**      | Explicit pixel value   | `width: 200`       |
| **Fractional** | Percentage of parent   | `width: 0.5` (50%) |
| **Fit**        | Shrink-wrap to content | `width: fit`       |


### Sizing Mode Combinations

The `SizingMode` enum represents all combinations:

```v ignore
pub enum SizingMode {
    fixed_fixed           // Both axes fixed
    fixed_fractional      // Width fixed, height fractional
    fixed_fit             // Width fixed, height fits content
    fractional_fixed      // Width fractional, height fixed
    fractional_fractional // Both axes fractional
    fractional_fit        // Width fractional, height fits
    fit_fixed             // Width fits, height fixed
    fit_fractional        // Width fits, height fractional
    fit_fit               // Both axes fit content
    // ... additional combinations with max constraints
}
```

## Width Calculation (`layout_widths`)

Width calculation traverses the tree in a specific order depending on axis:

### Left-to-Right (Row)
```
Parent width = sum(children widths) + spacing*(n-1) + padding
```

### Top-to-Bottom (Column)
```
Parent width = max(children widths) + padding
```

### Algorithm

```
for each layout (bottom-up for fit, top-down for fixed/fractional):
    if sizing is fixed:
        width = explicit value
    else if sizing is fractional:
        width = parent.available_width * fraction
    else if sizing is fit:
        width = calculated content width

    apply min/max constraints
    add border width
```

## Height Calculation (`layout_heights`)

Similar to width, but accounts for text wrapping:

### Left-to-Right (Row)
```
Parent height = max(children heights) + padding
```

### Top-to-Bottom (Column)
```
Parent height = sum(children heights) + spacing*(n-1) + padding
```

## Position Calculation (`layout_positions`)

Positions are calculated top-down after sizes are known:

```
for each child:
    x = parent.x + padding_left + accumulated_width
    y = parent.y + padding_top + accumulated_height

    apply alignment adjustments
    apply scroll offsets
```

### Alignment

Alignment adjusts position based on remaining space:

| H-Align   | Behavior                    |
|-----------|-----------------------------|
| `.left`   | No adjustment               |
| `.center` | x += (available - used) / 2 |
| `.right`  | x += (available - used)     |

| V-Align   | Behavior                    |
|-----------|-----------------------------|
| `.top`    | No adjustment               |
| `.middle` | y += (available - used) / 2 |
| `.bottom` | y += (available - used)     |


## Floating Layouts

Floating layouts (tooltips, dropdowns, context menus) are extracted from the tree and processed
separately:

1. **Extract**: Remove floating layouts from parent
2. **Calculate parent**: Run pipeline on main layout
3. **Calculate floating**: Run pipeline on each floating layout
4. **Render order**: Floating layouts render after main layout (on top)

## Scroll Containers

Scroll containers use `id_scroll` to track scroll state:

```v ignore
// In ViewState
scroll_x: map[u32]f32  // [id_scroll] -> horizontal offset
scroll_y: map[u32]f32  // [id_scroll] -> vertical offset
```

The scroll offset affects child positions but not the container itself.

## Performance Characteristics

- **Time Complexity**: O(n × p) where n = widgets, p = passes (10)
  - Simplified to O(n) since p is constant
- **Space Complexity**: O(n) for layout tree, O(d) for recursion stack (d = depth)
- **Optimization**: Early exit when layout unchanged (via `refresh_window` flag)

## Common Layout Patterns

### Centering Content
```v ignore
column(
    h_align: .center
    v_align: .middle
    sizing: fixed_fixed
    width: parent_width
    height: parent_height
    content: [...]
)
```

### Responsive Width with Fixed Height
```v ignore
button(
    width: 0.9      // 90% of parent
    height: 44      // Fixed 44px
    sizing: fractional_fixed
)
```

### Shrink-wrap Container
```v ignore
row(
    sizing: fit_fit  // Size to content
    content: [...]
)
```

### Scrollable List
```v ignore
column(
    id_scroll: 1
    scroll_mode: .vertical
    height: 300     // Fixed viewport
    content: [
        // Items taller than 300px
    ]
)
```

## Debugging Layout

Enable debug mode to see layout statistics:

```v ignore
mut window := gui.window(
    debug_layout: true
    // ...
)

// After rendering, check stats:
println(window.layout_stats)
```

## Related Files

- `layout.v` - Main layout arrangement logic
- `layout_pipeline.v` - Individual pipeline passes
- `layout_sizing.v` - Sizing mode definitions
- `shape.v` - Shape structure with layout properties
- `float_attach.v` - Floating layout positioning
