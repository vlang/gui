# Roadmap

This file is a forward-only todo list for professional-grade `v-gui`.

## Legend

- `[ ]` not started
- `[-]` do not implement
- `[?]` unsure
- `[x]` shipped

## Baseline Shipped

- [x] Immediate-mode rendering, retained layout tree, theme system, animation stack
- [x] Core widgets: input, button family, table, tree, markdown, dialogs, menus
- [x] SVG + shaders + gradients + blur + shadows
- [x] IME, clipboard text, async image loading, drag/drop inbound files
- [x] Desktop targets: macOS, Windows, Linux

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

### Data-Heavy UI

- [x] Virtualized list view (windowed rows, stable item identity)
- [x] Data grid v2: virtual rows, sort, filter, resize/reorder/pin columns
- [ ] Tree virtualization + lazy node loading
- [x] Cell editors for grid/list (text, select, date, checkbox)
- [ ] Charting/Graphs/Plottong package (external lib)

## 2026 H2: Accessibility + Globalization + Scale (P0/P1)

### Accessibility (A11y)

#### Phase 1 — Metadata Model (cross-platform)

##### 1. `AccessRole` enum (new file `a11y.v`)

35-value `u8` enum on Shape. Zero value `.none` = invisible to
a11y tree. Maps 1:1 to NSAccessibilityRole (macOS) / UIA Control
Type (Windows).

```v ignore
pub enum AccessRole as u8 {
    none
    button
    checkbox
    color_well
    combo_box
    date_field
    dialog
    disclosure
    grid
    grid_cell
    group
    heading
    image
    link
    list
    list_item
    menu
    menu_bar
    menu_item
    progress_bar
    radio_button
    radio_group
    scroll_area
    scroll_bar
    slider
    splitter
    static_text
    switch_toggle
    tab
    tab_item
    text_field
    text_area
    toolbar
    tree
    tree_item
}
```

##### 2. `AccessState` bitfield

`u16` on Shape, follows `Modifier` pattern from `event.v`.
`disabled` excluded — `Shape.disabled` already exists.

```v ignore
pub enum AccessState as u16 {
    none      = 0
    expanded  = 1    // disclosure/expand_panel open
    selected  = 2    // tab, list item, menu item
    checked   = 4    // toggle, checkbox
    required  = 8    // form validation
    invalid   = 16   // form validation error
    busy      = 32   // async loading / progress
    read_only = 64   // non-editable text field
    modal     = 128  // dialog
}

pub fn (s AccessState) has(flag AccessState) bool {
    return u16(s) & u16(flag) > 0 || s == flag
}
```

##### 3. `AccessInfo` sub-struct

Heap-allocated, nil when unused. Same lazy-alloc pattern as
`EventHandlers` / `TextConfig` / `ShapeEffects`.

```v ignore
@[heap]
pub struct AccessInfo {
pub mut:
    label         string  // primary screen-reader label
    description   string  // extended help text
    value_text    string  // current value (live buffer)
    value_num     f32     // numeric value (slider, progress)
    value_min     f32     // range minimum
    value_max     f32     // range maximum
    heading_level u8      // 1-6 for headings, 0 otherwise
}
```

Only allocated when at least one field is meaningful. Helper:

```v ignore
@[inline]
pub fn (shape &Shape) has_a11y() bool {
    return shape.a11y != unsafe { nil }
}
```

##### 4. Shape struct changes (+11 bytes)

| Field | Type | Bytes | Placement |
|-------|------|-------|-----------|
| `a11y_role` | `AccessRole` | 1 | with 1-byte enums |
| `a11y_state` | `AccessState` | 2 | after `a11y_role` |
| `a11y` | `&AccessInfo` | 8 | with `events`/`tc`/`fx` |

Role and state are value types — zero cost when `.none`.
Pointer stays nil for shapes without string/numeric metadata.

##### 5. Widget Cfg changes

Every interactive Cfg gains two `pub:` fields (empty-string
defaults, zero cost when unused):

```v ignore
a11y_label       string  // override auto-derived label
a11y_description string  // extended help text
```

Roles, states, and values auto-set in each widget's
`generate_layout()`. Button requires explicit `a11y_label`
(no auto-derive from `content []View`).

##### 6. Widget mapping table

**Roles and label sources:**

| Widget | `AccessRole` | Label source |
|--------|--------------|--------------|
| `button` | `.button` | `a11y_label` (explicit) |
| `toggle` / `checkbox` | `.checkbox` | `cfg.label` |
| `radio` | `.radio_button` | `cfg.label` |
| `radio_button_group` | `.radio_group` | `cfg.title` |
| `switch` | `.switch_toggle` | `cfg.label` |
| `input` | `.text_field` | `cfg.placeholder` |
| `input` (multiline) | `.text_area` | `cfg.placeholder` |
| `numeric_input` | `.text_field` | `cfg.placeholder` |
| `input_date` | `.date_field` | `cfg.placeholder` |
| `select` | `.combo_box` | `cfg.placeholder` |
| `range_slider` | `.slider` | `cfg.id` (fallback) |
| `progress_bar` | `.progress_bar` | `cfg.text` |
| `tab_control` | `.tab` | `cfg.id` |
| `tab_item` | `.tab_item` | `cfg.label` |
| `expand_panel` | `.disclosure` | — |
| `tree` | `.tree` | `cfg.id` |
| `tree_node` | `.tree_item` | `cfg.text` |
| `dialog` | `.dialog` | `cfg.title` |
| `menu` / `menubar` | `.menu_bar` | `cfg.id` |
| `menu_item` | `.menu_item` | `cfg.text` |
| `breadcrumb` | `.toolbar` | `cfg.id` |
| `breadcrumb_item` | `.link` | `cfg.label` |
| `splitter` | `.splitter` | `cfg.id` |
| `data_grid` | `.grid` | — |
| `listbox` | `.list` | `cfg.id` |
| `color_picker` | `.color_well` | `cfg.id` |
| `image` | `.image` | `cfg.id` / `cfg.src` |
| `svg` | `.image` | `cfg.id` |
| `markdown` | `.group` | — |
| `text` | `.static_text` | auto |
| `container` (titled) | `.group` | `cfg.title` |
| `container` (scroll) | `.scroll_area` | — |
| `container` (plain) | `.none` | — |
| `scrollbar` | `.scroll_bar` | — |

All `a11y_label` overrides take priority over auto-derived
labels.

**State auto-derivation:**

| Widget | Flags | Source |
|--------|-------|--------|
| `toggle` / `checkbox` | `.checked` | `cfg.select` |
| `radio` | `.selected` | `cfg.select` |
| `switch` | `.checked` | `cfg.select` |
| `expand_panel` | `.expanded` | `cfg.open` |
| `tab_item` (active) | `.selected` | active index |
| `menu_item` (active) | `.selected` | focus state |
| `progress_bar` (indef.) | `.busy` | indefinite flag |
| `dialog` | `.modal` | always |
| `input` (readonly) | `.read_only` | focus/editable |
| form field (errors) | `.invalid` | validation |
| form field (required) | `.required` | validator |

**Value auto-derivation:**

| Widget | `value_text` | `value_num` | min/max |
|--------|-------------|-------------|---------|
| `input` | live buffer | — | — |
| `numeric_input` | formatted | `cfg.value` | cfg |
| `range_slider` | — | `cfg.value` | cfg |
| `progress_bar` | percent | `cfg.percent` | 0–1 |
| `select` | joined sel. | — | — |

Internally generated shapes (data_grid column headers,
listbox items, markdown headings with `heading_level`) also
receive appropriate roles.

##### 7. New files

- [ ] `a11y.v` — `AccessRole`, `AccessState` + `.has()`,
      `AccessInfo`, `has_a11y()` helper
- [ ] `_a11y_test.v` — unit tests (bitfield logic, nil guard,
      enum boundaries) + integration tests (Cfg → layout →
      verify roles/labels/states on Shape tree)

##### 8. Verification checklist

- [ ] `v build .` compiles clean
- [ ] `v test .` passes (existing + new `_a11y_test.v`)
- [ ] `v fmt -w a11y.v shape.v` formatted
- [ ] Every widget with `id_focus > 0` emits
      `a11y_role != .none`
- [ ] `AccessState.has()` works for single + combined flags
- [ ] `has_a11y()` returns false when no a11y data set
- [ ] `a11y_label` override beats auto-derived label
- [ ] No heap allocation for shapes without a11y strings
      (role/state are value types; `&AccessInfo` stays nil)
- [ ] Shape struct size increase is exactly 11 bytes
- [ ] Showcase app runs without visual regression

#### Phase 2 — macOS NSAccessibility Backend

- [ ] Objective-C bridge (`a11y_macos.m`) implementing
      NSAccessibility protocol on a custom
      NSAccessibilityElement tree
- [ ] Layout-tree → a11y-tree sync each frame (diff-based or
      full rebuild)
- [ ] Focus-change notifications via
      NSAccessibilityFocusedUIElementChangedNotification
- [ ] Value-change / layout-change notifications
- [ ] Action dispatch (press, increment/decrement, confirm,
      cancel) routed back to Shape event handlers
- [ ] VoiceOver smoke tests for showcase app

#### Phase 3 — Widget Compliance

- [ ] Screen-reader roles/labels/states for every shipped
      widget (button, input, select, table, tree, tab_control,
      slider, checkbox, dialog, menu, breadcrumb, splitter,
      progress_bar)
- [ ] Keyboard parity matrix: tab, arrows, home/end,
      page up/down, escape, space/enter for activation
- [ ] Live-region announcements for dynamic content (toasts,
      progress updates, validation errors)

#### Phase 4 — Visual Accessibility

- [ ] High-contrast theme preset
- [ ] Visible focus ring system (themeable width, color, offset)
- [ ] `prefers-reduced-motion` detection → disable animations
- [ ] Minimum-contrast validation helper for custom themes

### Internationalization (i18n/l10n)

- [x] Locale service (number/date/time/currency formatting)
- [x] BiDi-aware UI mirroring for RTL layouts (not only text shaping)
- [x] Translation bundle loading + runtime language switch
- [x] Input method edge-case suite (dead keys, surrogate pairs, mixed scripts)

###     Performance

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

## Suggested First 10 Tickets

- [x] Input mask core + tests
- [x] Native open/save/folder dialogs (macOS first)
- [x] Markdown code highlighting (inline + fenced)
- [x] Tab control component
- [x] Splitter component
- [x] Virtualized list view
- [x] Data grid v2 foundations
- [ ] Accessibility role model + macOS backend
- [ ] Inspector overlay MVP
- [ ] Snapshot test harness
