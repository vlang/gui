# Roadmap

This file is a forward-only todo list for professional-grade `v-gui`.

## Legend

- `[ ]` not started
- `[-]` will not do
- `[?]` unsure
- `[x]` shipped

## Baseline Shipped

- [x] Immediate-mode rendering, retained layout tree, theme system, animation stack
- [x] Core widgets: input, button family, table, tree, markdown, dialogs, menus
- [x] SVG + shaders + gradients + blur + shadows
- [x] IME, clipboard text, async image loading, drag/drop inbound files
- [x] Desktop targets: macOS, Windows, Linux
- [x] Print: native OS print dialog, PDF export, raster export

## 2026 H1: Professional Desktop Baseline (P0)

### Input + Forms

- [x] Input masking engine (`9`, `a`, `*`, literals, escaped tokens, custom tokens)
- [x] Ready masks: phone, date, time, credit card, postal, SSN
- [x] Numeric input view with locale-aware parse/format and step controls
- [x] Currency/percent input modes with round-trip-safe formatting
- [x] Form validation model: sync/async validators, touched/dirty state, error slots
- [x] Unified input formatter pipeline (pre-commit transform + post-commit normalize)

### Native Desktop Dialogs

- [x] Native open-file dialog (single + multi-select, extension filters)
- [x] Native save-file dialog (default extension, overwrite handling)
- [x] Native folder-picker dialog
- [?] Native color picker dialog
- [ ] Native message/alert fallback adapter (opt-in over custom GUI dialog)
- [ ] Permission + sandbox-safe path handling on macOS/Windows/Linux portals

### Markdown + Rich Text

- [x] Markdown fenced code syntax highlighting (language-tag driven)
- [?] Theme-aware code highlight palettes (dark/light + custom themes)
- [-] Incremental markdown re-render (avoid full rebuild for small edits)
- [-] Offline mode for mermaid/math renderers (local backend option)
- [ ] Link context menu support (copy/open/inspect target)
- [x] Copy code block enhancement

### Missing Core Components

- [x] `tab_control` advanced features (reorder, close button, overflow menu)
- [x] `splitter` / pane divider widget (drag, collapse, min/max pane size)
- [x] `breadcrumb_bar` widget
- [ ] `command_palette` widget (search + ranking + keyboard-first UX)
- [ ] `toast` / non-blocking notification system
- [ ] `combobox` with typeahead filter and async options provider
- [ ] `badge` numeric and colored label
- [-] `toolbar` widget (button groups, separators, overflow menu)
- [-] `status_bar` widget (icon + text sections, embedded progress indicator)
- [ ] `skeleton` shimmer placeholder for async-loading content
- [x] `sidebar` widget with animated show/hide (spring/tween, overlay or push mode)

### Data-Heavy UI

- [x] Virtualized list view (windowed rows, stable item identity)
- [x] Data grid v2: virtual rows, sort, filter, resize/reorder/pin columns
- [x] Tree virtualization + lazy node loading
- [x] Cell editors for grid/list (text, select, date, checkbox)
- [ ] Charting/graphs/plotting package (external lib)

### Interaction

- [ ] In-app drag-to-reorder (list rows, tree nodes, tab strip)
- [ ] App-level hotkey registration (configurable shortcut map, conflict detection)
- [ ] System color-scheme detection → automatic dark/light theme switch

## 2026 H2: Globalization

### Internationalization (i18n/l10n)

- [x] Locale service (number/date/time/currency formatting)
- [x] BiDi-aware UI mirroring for RTL layouts (not only text shaping)
- [x] Translation bundle loading + runtime language switch
- [x] Input method edge-case suite (dead keys, surrogate pairs, mixed scripts)

### Performance

- [?] Dirty-region rendering
- [?] Layout cache with strict invalidation rules
- [-] Renderer batching + draw-call reduction instrumentation
- [-] GPU text atlas / glyph cache tuning and diagnostics
- [-] Built-in frame timeline overlay (layout ms, render ms, event ms)

## 2027+: Platform Expansion (P1/P2)

- [ ] Multi-window API (owned windows, modal ownership, shared resources)
- [ ] Docking layout system (IDE-style panels, drag docking targets)
- [ ] System tray integration on all desktop targets
- [ ] Native notifications API
- [ ] Outbound OS drag/drop (text/files/custom payloads)
- [ ] Carousel / pager widget (touch-friendly slide view, snap points)
- [ ] Multi-touch / trackpad gesture API (pinch, swipe, rotate)
- [ ] Mobile target spike (gesture model, safe area, virtual keyboard insets)
- [ ] Web target spike (Wasm renderer + browser clipboard/input backends)

## Quality + DevEx Track (Always On)

- [ ] Runtime inspector overlay (view tree, bounds, style, event trace)
- [x] Component gallery app with state permutations and edge-case fixtures
- [-] Snapshot/golden rendering tests per widget/state
- [x] Parser fuzzing for markdown/svg/url handlers
- [ ] Memory + resource leak CI checks
- [ ] API stability policy (versioning, deprecation windows, migration notes)
- [x] Public benchmark suite (widgets count tiers, text-heavy, svg-heavy scenarios)
