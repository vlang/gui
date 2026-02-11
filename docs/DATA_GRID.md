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
- Controlled column chooser (`show_column_chooser`, `hidden_column_ids`)
- Group headers (`group_by`) with optional aggregates
- Controlled master-detail rows
- Controlled row edit mode + typed cell editors (`text/select/date/checkbox`)
- Conditional cell formatting (`on_cell_format`)
- Controlled pagination (`page_size`, `page_index`)
- Controlled top frozen rows (`frozen_top_row_ids`)
- Optional frozen header row (`freeze_header`)
- Clipboard copy (`ctrl/cmd+c`) to TSV
- CSV import helper
- CSV helper export
- XLSX helper export
- PDF helper export

## Core Types
- `DataGridCfg`
- `GridColumnCfg`
- `GridCellEdit`
- `GridCsvData`
- `GridAggregateCfg`
- `GridRow`
- `GridQueryState`
- `GridSelection`

## Controlled Model
Application state owns query, selection, and rows.
Application also owns optional `column_order`, pin state (`GridColumnCfg.pin`),
column visibility (`hidden_column_ids`), grouping (`group_by`, `aggregates`),
detail expansion map (`detail_expanded_row_ids`), and frozen top row ids
(`frozen_top_row_ids`)
along with conditional format logic, row cell data updates for edits, and
pagination state (`page_size`, `page_index`).

Grid emits callbacks:
- `on_query_change`
- `on_selection_change`
- `on_column_order_change`
- `on_column_pin_change`
- `on_hidden_columns_change`
- `on_page_change`
- `on_cell_edit`
- `on_cell_format`
- `on_detail_expanded_change`
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

## Import and Export Helpers

```v ignore
parsed := gui.grid_data_from_csv(csv_data) or { panic(err) }
columns := parsed.columns
rows := parsed.rows

tsv := gui.grid_rows_to_tsv(columns, rows)
csv := gui.grid_rows_to_csv(columns, rows)
xlsx := gui.grid_rows_to_xlsx(columns, rows) or { []u8{} }
pdf := gui.grid_rows_to_pdf(columns, rows)
```

File helpers:

```v ignore
gui.grid_rows_to_xlsx_file('/tmp/grid.xlsx', columns, rows) or {}
gui.grid_rows_to_pdf_file('/tmp/grid.pdf', columns, rows) or {}
```

## Notes
- `table` remains available and unchanged.
- `data_grid` is for heavier interactive tabular workflows.
- Tab order follows numeric `id_focus` sort, not visual tree order.
- Avoid hashed focus ids for ordered header navigation. Hash order is unstable.
- Prefer reserved focus-id ranges per grid, then assign sequential header ids left->right.
- Keep ranges non-overlapping across sibling widgets to avoid collisions and tab-order corruption.
- Grouping is contiguous. Sort data by group columns first for stable large groups.
- Master-detail is controlled. App owns expanded ids and detail row content callback.
- Row editing is controlled. App applies `on_cell_edit` updates to row data.
- Conditional cell formatting is callback-driven via `on_cell_format`.
- Provide stable unique `GridRow.id` values. Empty ids use best-effort auto ids.
- `grid_data_from_csv` creates 1-based row ids and normalizes column ids.
- Top frozen rows are controlled via `frozen_top_row_ids`.
- Frozen rows are scoped to current page and keep current visible order.
- Frozen rows bypass group header generation and keep row/detail interactions.
- Enable `freeze_header` to keep the header row visible while vertical scrolling.
- Enter edit mode with row double-click or `F2` on active row.
- Exit edit mode with `Esc` (or `Enter` in text editor).
- Pagination is controlled. Grid emits next page index via `on_page_change`.
- Column chooser is controlled. Grid emits hidden-id map via `on_hidden_columns_change`.

## Header Keyboard
- `Tab` focuses header cells (left->right), not per-icon controls.
- `Left` / `Right`: move header focus.
- `Space` or `Enter`: toggle sort (`Shift` appends in multi-sort mode).
- `Ctrl`/`Cmd` + `Left` / `Right`: reorder current column.
- `Alt` + `Left` / `Right`: resize column by step.
- `Shift` + `Alt` + `Left` / `Right`: resize by larger step.
- `P`: cycle pin (`none -> left -> right -> none`).
- `Esc`: return focus to grid body.

## Body Keyboard
- `F2`: enter edit mode for active row (first editable column focused).
- `Esc`: exit row edit mode.
- `Ctrl`/`Cmd` + `PageUp` / `PageDown`: previous/next page.
- `Alt` + `Home` / `End`: first/last page.
