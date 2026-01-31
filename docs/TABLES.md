# Table Widget

v-gui provides a flexible table widget for displaying tabular data. Tables support multiple border
styles, row selection, column alignment, alternating row colors, and virtualized scrolling for
large datasets.

## Basic Usage

### Helper Functions

The easiest way to build tables is with helper functions:

```v ignore
window.table(
    data: [
        gui.tr([gui.th('First'), gui.th('Last'),     gui.th('Email')]),
        gui.tr([gui.td('Matt'),  gui.td('Williams'), gui.td('matt@example.com')]),
        gui.tr([gui.td('Clara'), gui.td('Nelson'),   gui.td('clara@example.com')]),
        gui.tr([gui.td('Frank'), gui.td('Johnson'),  gui.td('frank@example.com')]),
    ]
)
```

| Helper | Purpose |
|--------|---------|
| `tr(cells)` | Create a table row from cells |
| `th(text)` | Create a header cell |
| `td(text)` | Create a data cell |

### Full Configuration

For more control, use `TableRowCfg` and `TableCellCfg` directly:

```v ignore
window.table(
    id: 'users-table'
    border_style: .horizontal
    size_border: 1
    color_border: gui.gray
    text_style_head: gui.theme().b2
    data: [
        gui.TableRowCfg{
            cells: [
                gui.TableCellCfg{value: 'Name', head_cell: true},
                gui.TableCellCfg{value: 'Email', head_cell: true},
            ]
        },
        // ... data rows
    ]
)
```

## Data Sources

### Manual Configuration

Build rows and cells explicitly for full control:

```v ignore
mut rows := []gui.TableRowCfg{}
rows << gui.tr([gui.th('Col A'), gui.th('Col B')])
for item in data {
    rows << gui.tr([gui.td(item.a), gui.td(item.b)])
}
window.table(data: rows)
```

### From Data Array

Convert a `[][]string` directly:

```v ignore
data := [
    ['Name', 'Age', 'City'],
    ['Alice', '30', 'NYC'],
    ['Bob', '25', 'LA'],
]
table_cfg := gui.table_cfg_from_data(data)
window.table(table_cfg)
```

### From CSV

Parse CSV strings directly:

```v ignore
csv_data := 'Name,Age,City
Alice,30,NYC
Bob,25,LA'

// Returns View with error handling
window.table_from_csv_string(csv_data)

// Or get TableCfg for customization
table_cfg := gui.table_cfg_from_csv_string(csv_data)!
window.table(gui.TableCfg{
    ...table_cfg
    border_style: .horizontal
})
```

## Border Styles

Four border styles are available via `TableBorderStyle`:

```v ignore
window.table(border_style: .all)          // Full grid (default)
window.table(border_style: .horizontal)   // Lines between rows only
window.table(border_style: .header_only)  // Single line under header
window.table(border_style: .none)         // No borders
```

| Style | Description |
|-------|-------------|
| `.all` | Full grid with borders around every cell |
| `.horizontal` | Horizontal lines between all rows |
| `.header_only` | Single line separating header from data |
| `.none` | No borders (use with `color_row_alt` for zebra stripes) |

### Header Separator Override

For `.header_only` style, use a thicker header separator:

```v ignore
window.table(
    border_style: .header_only
    size_border: 1
    size_border_header: 2  // thicker line under header
)
```

## Selection

Tables support single and multi-select modes:

```v ignore
window.table(
    selected: app.selected_rows       // map[int]bool of selected row indices
    multi_select: true                // allow multiple selections
    on_select: fn (selected map[int]bool, row_idx int, mut e gui.Event, mut w gui.Window) {
        mut app := w.state[App]()
        app.selected_rows = selected.clone()
    }
    data: rows
)
```

Selection state is maintained externally in your app state. The `on_select` callback receives:
- `selected`: Map of all currently selected row indices
- `row_idx`: The row that was just clicked
- `e`: Event (mark `is_handled` to prevent bubbling)
- `w`: Window for state access

## Styling

### Column Alignment

Align columns independently:

```v ignore
window.table(
    align_head: .center                           // header alignment (default)
    column_alignments: [.left, .right, .center]   // per-column data alignment
    data: rows
)
```

### Alternating Row Colors

Zebra striping for readability:

```v ignore
window.table(
    color_row_alt: gui.Color{32, 32, 32, 255}
    border_style: .none  // often combined with no borders
    data: rows
)
```

### Text Styles

Customize header and cell text:

```v ignore
window.table(
    text_style_head: gui.theme().b2   // bold header
    text_style: gui.theme().n3        // normal cells
    data: rows
)
```

### Cell Padding

```v ignore
window.table(
    cell_padding: gui.padding(8, 12, 8, 12)
    data: rows
)
```

### Hover and Selection Colors

```v ignore
window.table(
    color_hover: gui.theme().color_hover
    color_select: gui.theme().color_select
    data: rows
)
```

## Scrolling and Virtualization

For large tables, enable scrolling and virtualization:

```v ignore
window.table(
    id: 'large-table'        // required for column width caching
    id_scroll: 1             // enable scrolling
    max_height: 400          // constrain height to enable scroll
    data: large_dataset      // thousands of rows OK
)
```

Virtualization automatically renders only visible rows, maintaining 60 FPS even with thousands of
rows. The table estimates row height and renders a buffer of rows above/below the viewport.

### Scrollbar Control

```v ignore
window.table(
    id_scroll: 1
    scrollbar: .auto    // show when needed (default)
    // scrollbar: .hidden  // never show
)
```

## Custom Cell Content

Override default text rendering with custom views:

```v ignore
gui.TableCellCfg{
    value: 'Delete'
    content: gui.button(
        content: [gui.text(text: 'Delete')]
        on_click: fn [row_id] (_, _, mut w gui.Window) {
            // handle delete
        }
    )
}
```

The `content` field accepts any `View`, enabling buttons, icons, progress bars, or other widgets
in cells.

## Column Widths

Column widths are calculated automatically based on content:

- Widths are computed by measuring text in each cell
- Minimum width enforced via `column_width_min` (default: 20)
- Default width for empty columns via `column_width_default` (default: 50)
- **Important**: Set `id` on tables with many rows to enable width caching

### Cache Management

```v ignore
// Clear cache for specific table (after data changes)
window.clear_table_cache('my-table')

// Clear all table caches
window.clear_all_table_caches()
```

## Examples

### Sortable Columns

```v ignore
fn table_with_sort(mut data TableData, mut window gui.Window) gui.View {
    mut cfg := gui.table_cfg_from_data(data.rows)

    // Replace header cells with clickable versions
    mut headers := []gui.TableCellCfg{}
    for idx, cell in cfg.data[0].cells {
        headers << gui.TableCellCfg{
            ...cell
            value: cell.value + if data.sort_col == idx { ' ↓' } else { '' }
            on_click: fn [idx, mut data] (_, mut e gui.Event, mut w gui.Window) {
                data.sort_col = idx
                data.sort()
                e.is_handled = true
            }
        }
    }
    cfg.data[0] = gui.tr(headers)

    return window.table(cfg)
}
```

### Selection with Feedback

```v ignore
gui.column(content: [
    gui.text(text: 'Selected: ${app.selected.keys().join(", ")}'),
    window.table(
        selected: app.selected
        multi_select: true
        on_select: fn (sel map[int]bool, _, mut e gui.Event, mut w gui.Window) {
            w.state[App]().selected = sel.clone()
        }
        data: rows
    ),
])
```

### Full Example

See `examples/table_demo.v` for a complete demonstration including:
- All four border styles
- Single and multi-select
- CSV data loading
- Sortable columns
- Scrollable large tables

## TableCfg Reference

```v ignore
pub struct TableCfg {
pub:
    id                   string
    color_border         Color
    color_select         Color
    color_hover          Color
    color_row_alt        ?Color
    cell_padding         Padding
    text_style           TextStyle
    text_style_head      TextStyle
    align_head           HorizontalAlign
    column_alignments    []HorizontalAlign
    column_width_default f32
    column_width_min     f32
    size_border          f32
    size_border_header   f32
    border_style         TableBorderStyle
    width                f32
    height               f32
    min_width            f32
    max_width            f32
    min_height           f32
    max_height           f32
    sizing               Sizing
    id_scroll            u32
    scrollbar            ScrollbarOverflow
    multi_select         bool
    selected             map[int]bool
    on_select            fn (map[int]bool, int, mut Event, mut Window)
pub mut:
    data []TableRowCfg
}
```

## Performance Tips

1. **Always set `id`**: Tables with IDs cache column width calculations, avoiding expensive
   re-measurement on every frame.

2. **Use virtualization**: Set `id_scroll` and `max_height` for tables over ~50 rows. Only visible
   rows are rendered.

3. **Batch data updates**: When updating many rows, modify the data array in one operation rather
   than individual cell updates.

4. **Clear cache on data change**: Call `window.clear_table_cache(id)` after significant data
   changes to recalculate column widths.
