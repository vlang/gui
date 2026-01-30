Plan: Table Widget Missing Features

Current State

view_table.v (234 lines) provides basic tabular layout with:
- Nested rows/cells with per-cell click handlers
- CSV import, text styling, borders, cell hover
- Auto column width calculation

Missing Features (vs listbox/select/tree widgets)

Priority 1: Core Table Features

1. Row Selection
- Add selected []int or selected []string to track selected rows
- Add color_select for selection highlight
- Add on_select callback
- Support single/multi-select modes
2. Row-Level Interactions
- Add on_click to TableRowCfg (not just cells)
- Add row hover highlighting (color_hover)
- Add row ID for tracking
3. Scroll Integration
- Add id_scroll field
- Wrap table in scrollable container

Priority 2: Visual Enhancements

4. Alternating Row Colors
- Add color_row_alt for zebra striping
- Apply to even/odd rows automatically
5. Sizing Constraints
- Add width, height, min_width, max_width, min_height, max_height

Priority 3: Keyboard & Focus

6. Keyboard Navigation
- Add id_focus field
- Arrow keys to navigate rows
- Enter to select, Escape to deselect
7. Focus Styling
- Add color_focus, color_border_focus

Priority 4: Advanced (Optional)

8. Built-in Sorting - sortable column headers with indicators
9. Resizable Columns - drag column borders to resize
10. Frozen Header - header stays visible while scrolling

Implementation Order

1. Row selection + color_select + on_select
2. Row-level on_click + color_hover
3. id_scroll integration
4. Alternating row colors
5. Sizing constraints
6. Keyboard nav + focus styling

Files to Modify

- src/view_table.v - main implementation
- examples/table_demo.v - demo updates

Verification

- Run v fmt -w src/view_table.v
- Run table demo, verify selection/hover/scroll work
- Test keyboard navigation if implemented

Unresolved Questions

1. Single-select only or also multi-select?
2. Row selection by index or by row ID string?
3. Include keyboard nav in initial scope?
4. Include built-in sorting or leave to user?