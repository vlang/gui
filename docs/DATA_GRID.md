# Data Grid Widget

`data_grid` is a controlled, virtualized grid for tabular data.

## Features (v1)
- Virtual row rendering
- Single and multi-column sorting (shift-click)
- Per-column filter row + quick filter input
- Row selection: single, toggle, range
- Keyboard navigation + `ctrl/cmd+a`
- Column resize drag + double-click auto-fit
- Clipboard copy (`ctrl/cmd+c`) to TSV
- CSV helper export

## Core Types
- `DataGridCfg`
- `GridColumnCfg`
- `GridRow`
- `GridQueryState`
- `GridSelection`

## Controlled Model
Application state owns query, selection, and rows.

Grid emits callbacks:
- `on_query_change`
- `on_selection_change`
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
