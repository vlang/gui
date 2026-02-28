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
- [x] Native message/alert fallback adapter (opt-in over custom GUI dialog)
- [x] Permission + sandbox-safe path handling on macOS/Windows/Linux portals

### Markdown + Rich Text

- [x] Markdown fenced code syntax highlighting (language-tag driven)
- [?] Theme-aware code highlight palettes (dark/light + custom themes)
- [-] Incremental markdown re-render (avoid full rebuild for small edits)
- [-] Offline mode for mermaid/math renderers (local backend option)
- [x] Link context menu support (copy/open/inspect target)
- [x] Copy code block enhancement

### Missing Core Components

- [x] `tab_control` advanced features (reorder, close button, overflow menu)
- [x] `splitter` / pane divider widget (drag, collapse, min/max pane size)
- [x] `breadcrumb_bar` widget
- [x] `command_palette` widget (search + ranking + keyboard-first UX)
- [x] `toast` / non-blocking notification system
- [x] `combobox` with typeahead filter and async options provider
- [x] `badge` numeric and colored label
- [-] `toolbar` widget (button groups, separators, overflow menu)
- [-] `status bar` widget (icon + text sections, embedded progress indicator)
- [ ] `skeleton` shimmer placeholder for async-loading content
- [x] `sidebar` widget with animated show/hide (spring/tween, overlay or push mode)

### Data-Heavy UI

- [x] Virtualized list view (windowed rows, stable item identity)
- [x] Data grid v2: virtual rows, sort, filter, resize/reorder/pin columns
- [x] Tree virtualization + lazy node loading
- [x] Cell editors for grid/list (text, select, date, checkbox)
- [ ] Charting/graphs/plotting package (external lib; see section below)

### Interaction

- [x] In-app drag-to-reorder (list rows, tree nodes, tab strip)
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
- [x] Docking layout system (IDE-style panels, drag docking targets)
- [ ] System tray integration on all desktop targets
- [ ] Native notifications API
- [ ] Outbound OS drag/drop (text/files/custom payloads)
- [ ] Carousel / pager widget (touch-friendly slide view, snap points)
- [ ] Multi-touch / trackpad gesture API (pinch, swipe, rotate)
- [ ] Mobile target spike (gesture model, safe area, virtual keyboard insets)
- [ ] Web target spike (Wasm renderer + browser clipboard/input backends)

## Charting / Graphing / Plotting (External Package)

Separate package built on top of `gui`. Requires a canvas View in
the framework — a View that exposes a draw callback with direct
access to the GPU drawing primitives within a clipped layout region.

### Framework Prerequisites

- [ ] Canvas View: layout node with `on_draw` callback providing
      polyline, filled-polygon, and arc primitives
- [ ] Retained geometry buffer in canvas (avoid re-tessellation when
      only transform/pan/zoom changes)
- [x] Text measurement API (`get_text_width`, `line_height`)
- [x] Text rotation (`TextStyle.rotation_radians`)
- [x] Rectangular clipping (`clip: true` on containers)
- [x] Mouse events (hover, click, scroll, mouse_lock for drag)
- [x] Cursor control (crosshair, pointer, resize)
- [x] Floating overlays / tooltips
- [x] Gradient fills on shapes
- [x] Animation stack (tween, spring, keyframe)
- [x] Custom fragment shaders

### Chart Types (P0)

- [ ] Line chart (polyline, markers, multiple series)
- [ ] Bar chart (vertical/horizontal, grouped, stacked)
- [ ] Area chart (filled polyline, stacked)
- [ ] Pie / donut chart (arc segments, labels, explode)
- [ ] Scatter plot (point clouds, bubble variant)

### Chart Types (P1)

- [ ] Candlestick / OHLC (financial)
- [ ] Gauge / radial progress
- [ ] Heatmap (grid cells, color scale)
- [ ] Radar / spider chart
- [ ] Histogram (bin computation, density overlay)

### Axes + Scales

- [ ] Linear, logarithmic, time, and category scales
- [ ] Auto tick generation with label collision avoidance
- [ ] Axis title, grid lines, minor grid lines
- [ ] Multi-axis support (dual Y)
- [ ] Locale-aware number/date formatting on tick labels

### Chart Interaction

- [ ] Hover tooltip with nearest-point snapping
- [ ] Crosshair / guideline on hover
- [ ] Click-to-select data point / series
- [ ] Zoom (scroll wheel + drag-to-zoom box)
- [ ] Pan (mouse_lock drag)
- [ ] Legend toggle (show/hide series)

### Animation + Transitions

- [ ] Animated data entry (bars grow, lines draw-on)
- [ ] Smooth data update transitions (morph old → new)
- [ ] Series add/remove animation

### Data Model

- [ ] Typed series: `[]f64`, `[]TimeValue`, `[]XY`
- [ ] Lazy / streaming data provider interface
- [ ] Auto domain/range from data with optional overrides

### Theming + Style

- [ ] Inherit `gui` theme colors (foreground, background, accent)
- [ ] Configurable color palettes per chart
- [ ] Consistent text styles with framework `TextStyle`

## Quality + DevEx Track (Always On)

- [x] Runtime inspector overlay (view tree, bounds, style, event trace)
- [x] Component gallery app with state permutations and edge-case fixtures
- [-] Snapshot/golden rendering tests per widget/state
- [x] Parser fuzzing for markdown/svg/url handlers
- [x] Memory + resource leak CI checks
- [ ] API stability policy (versioning, deprecation windows, migration notes)
- [x] Public benchmark suite (widgets count tiers, text-heavy, svg-heavy scenarios)
