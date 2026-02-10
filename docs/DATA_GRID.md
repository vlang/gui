# Data Grid Widget

`data_grid` is a controlled, virtualized grid for tabular data.

## Features (v1)
- Virtual row rendering
- Single and multi-column sorting (shift-click)
- Per-column filter row + quick filter input
- Row selection: single, toggle, range
- Keyboard navigation + `ctrl/cmd+a`
- Header keyboard controls (sort/reorder/resize/pin/focus)
- Column resize drag + double-click auto-fit
- Controlled column reorder (`<` / `>` header controls)
- Controlled column pin cycle (`•` -> `↤` -> `↦`)
- Group headers (`group_by`) with optional aggregates
- Clipboard copy (`ctrl/cmd+c`) to TSV
- CSV helper export

## Core Types
- `DataGridCfg`
- `GridColumnCfg`
- `GridAggregateCfg`
- `GridRow`
- `GridQueryState`
- `GridSelection`

## Controlled Model
Application state owns query, selection, and rows.
Application also owns optional `column_order`, pin state (`GridColumnCfg.pin`),
and grouping (`group_by`, `aggregates`).

Grid emits callbacks:
- `on_query_change`
- `on_selection_change`
- `on_column_order_change`
- `on_column_pin_change`
- `on_row_activate`
- `on_copy_rows`

## Basic Example

```v ignore
import gui

@[heap]
struct App {
pub mut:
	query     gui.GridQueryState
	selection gui.GridSelection
	rows      []gui.GridRow
}

fn main_view(mut w gui.Window) gui.View {
	mut app := w.state[App]()
	return w.data_grid(
		id: 'users-grid'
		columns: [
			gui.GridColumnCfg{id: 'name', title: 'Name', width: 180},
			gui.GridColumnCfg{id: 'email', title: 'Email', width: 260},
		]
		rows: app.rows
		query: app.query
		selection: app.selection
		max_height: 360
		on_query_change: fn (q gui.GridQueryState, mut _ gui.Event, mut w gui.Window) {
			mut a := w.state[App]()
			a.query = q
		}
		on_selection_change: fn (s gui.GridSelection, mut _ gui.Event, mut w gui.Window) {
			mut a := w.state[App]()
			a.selection = s
		}
	)
}
```

## Export Helpers

```v ignore
tsv := gui.grid_rows_to_tsv(columns, rows)
csv := gui.grid_rows_to_csv(columns, rows)
```

## Notes
- `table` remains available and unchanged.
- `data_grid` is for heavier interactive tabular workflows.
- Tab order follows numeric `id_focus` sort, not visual tree order.
- Avoid hashed focus ids for ordered header navigation. Hash order is unstable.
- Prefer reserved focus-id ranges per grid, then assign sequential header ids left->right.
- Keep ranges non-overlapping across sibling widgets to avoid collisions and tab-order corruption.
- Grouping is contiguous. Sort data by group columns first for stable large groups.

## Header Keyboard
- `Tab` focuses header cells (left->right), not per-icon controls.
- `Left` / `Right`: move header focus.
- `Space` or `Enter`: toggle sort (`Shift` appends in multi-sort mode).
- `Ctrl`/`Cmd` + `Left` / `Right`: reorder current column.
- `Alt` + `Left` / `Right`: resize column by step.
- `Shift` + `Alt` + `Left` / `Right`: resize by larger step.
- `P`: cycle pin (`none -> left -> right -> none`).
- `Esc`: return focus to grid body.
