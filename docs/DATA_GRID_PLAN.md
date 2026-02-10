# Data Grid Plan

## Status
- Date: 2026-02-10
- Branch:
- PR/Issue:
- Current phase: Phase 2 complete
- Last completed acceptance check: `v test .`, `v check-md -w` docs + README

## Scope
- New `data_grid` API (controlled)
- Phase 1 bundle: core + sort/filter/select + resize + copy TSV
- Deferred: pin/reorder/group/master-detail/editors/XLSX/PDF

## Phases

### Phase A: Core + virtualization
- [x] Add `DataGridCfg`, row/column/query/selection types
- [x] Render header/body + virtual rows
- [x] Add `view_state` runtime caches for grid
- [x] Acceptance:
- [x] `v -check-syntax` changed files
- [x] `_view_data_grid_test.v` core tests pass

### Phase B: Sort + filter
- [x] Header sort interactions (single + shift multi-sort)
- [x] Filter row + quick filter callback events
- [x] Controlled query callback flow
- [x] Acceptance:
- [x] sort/filter tests pass

### Phase C: Selection + keyboard
- [x] Single/multi/range row selection
- [x] Keyboard nav (`up/down/home/end/page`, `ctrl/cmd+a`)
- [x] Controlled selection callback flow
- [x] Acceptance:
- [x] selection/nav tests pass

### Phase D: Resize + clipboard + CSV helper
- [x] Header drag resize + clamp + auto-fit
- [x] `ctrl/cmd+c` selected rows to TSV
- [x] Add `grid_rows_to_csv(...)`
- [x] Acceptance:
- [x] resize/copy/CSV tests pass

### Phase E: Docs + demo + hardening
- [x] Add `docs/DATA_GRID.md`
- [x] Add `examples/data_grid_demo.v`
- [x] Update `README.md`
- [x] Final format/lint/test checks
- [x] Acceptance:
- [x] `v fmt -w` changed `.v`
- [x] `v check-md -w docs/DATA_GRID_PLAN.md`
- [x] `v check-md -w docs/DATA_GRID.md`
- [x] `v check-md -w README.md`
- [x] `v test .`

## Decision Log
- [x] 2026-02-10: `data_grid` shipped as new API; existing `table` unchanged.
- [x] 2026-02-10: Phase 2 adds controlled column reorder + pinning.
- [x] 2026-02-10: Header keyboard tab order uses sequential focus ids; avoid hash-based ids.
- [x] 2026-02-10: Header keyboard shortcuts added for sort/reorder/resize/pin + focus return.

## Deferred Backlog
- [x] Column pinning
- [x] Column reorder
- [ ] Grouping + aggregation
- [ ] Master-detail rows
- [ ] Cell/row editors
- [ ] PDF/XLSX export
