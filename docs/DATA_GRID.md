# Data Grid Widget

`data_grid` is a controlled, virtualized grid for interactive tabular data.

## Modes

`data_grid` supports two modes:

- `rows` mode: app passes `rows` directly (existing controlled model).
- `data_source` mode: grid fetches rows via `DataGridDataSource`.

`rows` mode is still fully supported and unchanged.

## Data Source Model

Data-source mode centralizes server fetch via `fetch_data(req GridDataRequest)`.

Core pieces:

- `DataGridDataSource`
- `GridDataRequest`
- `GridDataResult`
- `GridDataCapabilities`
- `GridAbortController` / `GridAbortSignal`

### Request shape

- `grid_id`: source-aware request routing
- `query`: typed sort/filter/quick filter (`GridQueryState`)
- `page`: `GridCursorPageReq` or `GridOffsetPageReq`
- `signal`: cancellation token
- `request_id`: monotonic id for stale-response guards

### Result shape

- `rows`: returned page rows
- `next_cursor` / `prev_cursor`: cursor navigation tokens
- `row_count`: `?int`; use `none` when total unknown/infinite
- `has_more`: paging continuation hint
- `received_count`: returned row count for this page

### Capabilities metadata

`capabilities()` returns explicit support flags:

- `supports_cursor_pagination`
- `supports_offset_pagination`
- `supports_numbered_pages`
- `row_count_known`

Grid uses this metadata to select pagination behavior and display counts safely.

## Cursor-First Pagination

Use cursor pagination by default. It is stable for infinite scroll and changing data.

Offset pagination is supported for static snapshots and numbered-page workflows.

Set mode in `DataGridCfg`:

- `pagination_kind: .cursor` (default)
- `pagination_kind: .offset`

Set page size with `page_limit`.

## Cancellation and Race Safety

Grid starts async fetches and cancels stale requests automatically.

Internal behavior:

- each new fetch aborts the previous active request
- each response checks `request_id` before apply
- stale or aborted responses are ignored

This prevents scroll/filter race corruption.

## `DataGridCfg` additions

New fields:

- `data_source DataGridDataSource`
- `pagination_kind GridPaginationKind`
- `cursor string`
- `page_limit int`
- `row_count ?int`
- `loading bool`
- `load_error string`

When `data_source` is set, fetched rows are used for render. Local `rows` paging is disabled.

## Example: Data Source Mode

```v ignore
import gui

@[heap]
struct App {
pub mut:
	source    ?gui.DataGridDataSource
	query     gui.GridQueryState
	selection gui.GridSelection
}

fn view(mut w gui.Window) gui.View {
	mut app := w.state[App]()
	return w.data_grid(
		id:              'users-grid'
		columns:         columns()
		data_source:     app.source
		pagination_kind: .cursor
		page_limit:      200
		query:           app.query
		selection:       app.selection
		show_filter_row: true
		show_quick_filter: true
		on_query_change: fn (q gui.GridQueryState, mut _ gui.Event, mut w gui.Window) {
			w.state[App]().query = q
		}
		on_selection_change: fn (s gui.GridSelection, mut _ gui.Event, mut w gui.Window) {
			w.state[App]().selection = s
		}
	)
}
```

Built-in concrete sources:

- `InMemoryCursorDataSource`
- `InMemoryOffsetDataSource`

See `examples/data_grid_data_source_demo.v` for a 50k-row demo.

## Example: Rows Mode (unchanged)

```v ignore
window.data_grid(
	id: 'users-grid'
	columns: columns
	rows: rows
	query: app.query
	selection: app.selection
	on_query_change: on_query_change
	on_selection_change: on_selection_change
)
```

## Runtime Stats

Use runtime counters for diagnostics:

```v ignore
stats := window.data_grid_source_stats('users-grid')
```

Fields include loading/error/request counts and stale/cancel counters.

## Import/Export Helpers

These helpers are unchanged:

- `grid_data_from_csv`
- `grid_rows_to_tsv`
- `grid_rows_to_csv`
- `grid_rows_to_xlsx`
- `grid_rows_to_pdf`

## Notes

- `table` remains unchanged.
- Keep `GridRow.id` stable and unique.
- Grouping is contiguous; pre-sort by group keys for stable large groups.
- Row editing is controlled through `on_cell_edit`.
- Tab order follows numeric `id_focus`, not tree order.
