# Data Source Plan for `data_grid`

## Summary

Add a V-native data-source layer for `data_grid` with cursor-first pagination,
request cancellation, stale-response guards, typed query arguments, and capability
metadata. Keep existing `rows` mode compatible.

## Scope

- Add public `DataGridDataSource` API and request/result/capability types.
- Extend `DataGridCfg` for dual mode (`rows` or `data_source`).
- Implement async runtime loader in grid with cancellation + stale guards.
- Add multiple concrete data-source implementations.
- Add large-data sample app.
- Rewrite `docs/DATA_GRID.md` for data-source usage.

## Public API Additions

- `GridPaginationKind` (`.cursor`, `.offset`)
- `GridCursorPageReq`
- `GridOffsetPageReq`
- `GridPageRequest` (sum type)
- `GridAbortSignal`
- `GridAbortController`
- `GridDataRequest`
- `GridDataResult`
- `GridDataCapabilities`
- `DataGridDataSource`
- `InMemoryCursorDataSource`
- `InMemoryOffsetDataSource`
- `Window.data_grid_source_stats(grid_id string)`

## `DataGridCfg` Additions

- `data_source DataGridDataSource`
- `pagination_kind GridPaginationKind`
- `cursor string`
- `page_limit int`
- `row_count ?int`
- `loading bool`
- `load_error string`

Compatibility default: if `data_source` is nil, behavior matches old `rows` mode.

## Runtime Design

- Per-grid async state stored in `ViewState` (`data_grid_source_state`).
- State tracks rows/loading/error/request ids/cursor-offset/page metadata.
- Request key derives from query + paging token + page limit.
- New request aborts active request and increments counters.
- Apply callback checks request id; stale result ignored.
- `row_count` may remain `none` for unknown totals.

## Pagination Strategy

- Cursor mode default and preferred.
- Offset mode used when selected or cursor unsupported.
- Capability metadata drives fallback selection.
- Grid pager row adapts to source mode and unknown total counts.

## Request Cancellation

- `GridAbortController.abort()` flips signal state.
- Concrete sources check `signal.is_aborted()` before/after expensive work.
- Grid ignores aborted and stale responses.

## Concrete Implementations

- `InMemoryCursorDataSource`
  - supports cursor pagination
  - optional offset support
  - optional known/unknown row count
  - optional simulated latency
- `InMemoryOffsetDataSource`
  - offset-first behavior
  - numbered page support metadata
  - optional simulated latency

## Sample App

`examples/data_grid_data_source_demo.v`:

- 50,000 rows
- toggle cursor/offset mode
- toggle simulated latency
- server-side query path (sort/filter/quick filter)
- runtime stats display (requests/cancels/stales/loading)

## Docs

`docs/DATA_GRID.md` rewritten to include:

- dual mode explanation
- data-source core types
- cursor-first guidance
- cancellation/race model
- sample usage for source mode and rows mode

## Tests

Add `_data_source_test.v`:

- cursor paging behavior
- offset paging behavior
- query+sort+filter behavior
- abort-signal behavior
- pagination kind fallback behavior

Existing tests for `rows` mode remain valid.

## Acceptance Criteria

- Existing `rows` callers compile and run unchanged.
- Source mode fetches asynchronously and updates grid.
- Cancellation prevents stale/racing UI updates.
- Cursor mode works without total row count.
- Offset mode works for static datasets.
- Large source demo runs and stays responsive.
- Data-grid docs explain source setup and usage.
