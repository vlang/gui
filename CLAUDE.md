# GUI Framework — Developer Reference

Quick-start orientation for AI assistants and new contributors.
Framework: `gui/` module, immediate-mode declarative UI in V.

## Framework Overview

Immediate-mode pattern — every frame rebuilds the UI from a pure function.

Key types:

- **`Window`** (`window.v`) — owns the render loop, layout tree, animations,
  IME, A11y, and command queue. One per app.
- **`View`** (`view_*.v`) — interface; user-facing config structs that implement
  `generate_layout(mut Window) Layout`.
- **`Layout`** (`layout*.v`) — resolved node tree: shape + children. Output of
  `compose_layout`. Discarded each frame (full rebuild) or amended
  (render-only path).
- **`Shape`** (`shape*.v`) — drawing descriptor: geometry, color, optional
  sub-structs `tc &TextConfig`, `fx &ShapeEffects`, `&EventHandlers`.
- **`Renderer`** / `renderers_draw` — flat list of draw commands emitted by
  `render_layout`. Consumed once per frame by `renderers_draw`.

Example program convention: the first container must be `gui.fixed_fixed`
with width and height matching the window dimensions.

Entry point pattern:

```v ignore
gui.window(gui.WindowCfg{
    on_init: fn (mut w gui.Window) { w.update_view(my_view_fn) }
})
```

## Render Pipeline

```
frame_fn
  flush_commands          // thread-safe state mutations
  init_ime / init_a11y    // lazy first-frame init
  if refresh_layout       // full rebuild (view fn + layout + renderers)
    update()
      view_generator()    // calls user view fn
      compose_layout()    // View tree → Layout tree
        generate_layout   // View → Layout nodes
        layout_arrange    // size/position passes (amend_layout fires here)
      rebuild_renderers() // Layout tree → flat []Renderer
  else if refresh_render_only  // renderer rebuild only (layout reused)
    update_render_only()
      rebuild_renderers()
  process_svg_filters     // offscreen passes before swapchain
  renderers_draw()        // draw flat renderer list
```

Trigger full rebuild:   `w.update_window()` sets `refresh_layout = true`
Trigger render-only:    `w.rerender_window()` sets `refresh_render_only = true`
`refresh_layout` takes priority over `refresh_render_only`.

When to use each path:

| Condition | Path |
|-----------|------|
| View state changed (app data, focus, etc.) | `refresh_layout` |
| Animations with `render_only: true` | `refresh_render_only` |
| Cursor blink, progress bars | `refresh_render_only` |
| Tween / Spring / Hero transitions | `refresh_layout` |

**Important**: layout/hero transitions lerp from a snapshot to the current
position. Repeated `rerender` corrupts the interpolated values — use full
rebuild.

## Layout Pipeline

```
compose_layout(mut view)
  generate_layout(mut view, mut window)   // View → Layout (recursive)
  layout_arrange(mut layout, mut window)  // 3-pass: size, amend, position
    layout_sizes()         // distribute grow/shrink space (layout_sizing.v)
    amend_layout callbacks // user hooks run HERE (not in render_layout)
    layout_positions()     // x/y assignment, scroll offset clamping
  wrap root in transparent Shape
```

`amend_layout` runs during `layout_arrange`, **not** during `render_layout`.
Use it to mutate layout geometry or inject child layouts.

`render_cursor` runs during `render_layout`, reads `input_cursor_on` live
(never captured in a closure).

## GC / Boehm False-Retention Rules

V uses the Boehm conservative GC. Key hazards:

### 1. `array.clear()` retains stale pointers

`clear()` sets `len=0` but does **not** zero the backing memory. The GC scans
the entire allocated block, so stale pointers in cleared arrays cause false
retention (objects never collected).

**Rule**: use `array_clear(mut arr)` (defined in `gc.v`) for any array containing
pointers or pointer-containing types. It calls `vmemset` before zeroing `len`.

```v ignore
array_clear(mut window.renderers) // NOT window.renderers.clear()
```

### 2. Closure capture — full struct pointer

`fn [cfg]` closures capture the entire `@[heap]` cfg struct pointer.
Conservative GC scans ALL pointer-sized words in the struct → false retention
proportional to struct size.

**Rule**: extract only the fields needed into locals, then capture those:

```v ignore
// Bad — captures entire InputCfg (many pointer-sized fields):
on_char: fn [cfg] (l &Layout, mut e Event, mut w Window) { ... }

// Good — extract minimal fields:
id_focus := cfg.id_focus
color_hover := cfg.color_hover
on_char: fn [id_focus, color_hover] (l &Layout, mut e Event, mut w Window) { ... }
```

Bound methods stored as callbacks (`cv.method_name`) are closures too —
they capture `cv` pointer. Convert to standalone functions.

Applied to: `view_input.v` (root cause), `view_select.v`, `view_menubar.v`,
`view_color_picker.v`, `view_container.v` (tooltip), `view_input_date.v`,
`view_table.v`.

See `make_input_on_char`, `make_select_on_keydown`, `make_menubar_amend_layout`
for the extraction pattern.

### 3. Layout scrubbing between frames

Old `Layout` nodes must be freed between frames. `layout_clear` zeros and
frees each node's `Shape`. Guard: never free `empty_layout.shape` (module
constant).

## Shape Struct Layout

`Shape` uses optional sub-structs to reduce per-shape memory footprint:

| Field | Type | Contains | Default |
|-------|------|----------|---------|
| `tc` | `&TextConfig` | text, text_style, password flag, … | `unsafe{nil}` |
| `fx` | `&ShapeEffects` | shadow, gradient, border_gradient, shader, blur | `unsafe{nil}` |
| (events) | `&EventHandlers` | on_click, on_hover, on_key_down, … | `unsafe{nil}` |

Access: `shape.tc.text`, `shape.fx.shadow`. Always nil-check via `has_events()`.

Lazy alloc: range_slider / date_picker_roller allocate `&EventHandlers` on
first use; color_picker allocates `&ShapeEffects` for gradient.

`scrollbar_orientation ScrollbarOrientation` (1-byte enum) identifies scrollbar
shapes — the old `name string` field was removed.

`resource string` holds either `image_name` or `svg_name`, discriminated by
`shape_type`.

## Image Clipping to Rounded Containers

Containers with `clip: true` and `radius > 0` (or `circle()`) clip
child images to the rounded boundary via an SDF alpha-mask shader.

- `window.clip_radius` propagates during `render_layout` recursion and is composed
  per clip scope. Child clips reduce radius with `min(parent, child)`;
  non-rounded child clips inherit parent.
- `DrawImage.clip_radius > 0` triggers `draw_image_rounded()` in the
  dispatch — a custom SGL pipeline (`image_clip`) that samples the
  texture and applies SDF rounded-rect masking in the fragment shader.
- Inline RTF object images use the same `DrawImage` clip-radius path, so rounded
  clipping is consistent.
- `image_clip` init failure is latched and fallback warning is emitted once;
  fallback draws unclipped.
- Non-clipped images (`clip_radius == 0`) use the standard
  `ctx.draw_image` path unchanged.

```v ignore
gui.column(clip: true, radius: 40, width: 80, height: 80,
    content: [gui.image(src: "avatar.jpg", sizing: gui.fill_fill)])
gui.circle(clip: true, width: 80, height: 80,
    content: [gui.image(src: "avatar.jpg", sizing: gui.fill_fill)])
```

## V Language Gotchas

### Submodule import

```v ignore
import svg          // correct — short name
// import gui.svg   // wrong — "unknown type" errors
```

Same pattern: `import nativebridge`. V cannot resolve submodule types when
imported with the full parent-module path.

### `map[string][N]f32` bug

`map[string][6]f32` has broken `in` checks and optional access at the call
site. Passing such a map to a helper function while assigning to it silently
produces a zero matrix instead of identity — all geometry collapses to origin.

Workaround: direct assignment `m[key] = value` works. Do **not** extract a
helper that takes the map as a parameter. See `render_svg.v` `group_matrices`
for the inline comment.

### Pointer-based sumtype dangling pointers

`&SumType(Variant{...})` generates `to_sumtype(..., is_mut=true)` which
skips `memdup`. The variant lives as a stack temporary (compound literal).
After the enclosing function returns, the sumtype's pointer dangles.

**Workaround**: use a tagged struct with an enum discriminator instead of
a V sumtype for types needing heap persistence. See `DockNode` in
`dock_layout_tree.v`.

### Inline `if` returning `&T` vs `voidptr`

V cannot return `&T` from an inline `if` expression when the other branch
returns `voidptr`. Use a helper method returning `&T` with `unsafe { nil }`.

## i18n Bundle Update Checklist

When adding a `str_*` field to `Locale`:

1. `locale.v` — new field with en-US default
2. `locale_bundle.v` — `str_or(b.strings, …)` line in `to_locale()`
3. `locale_presets.v` — de-DE and ar-SA preset constants
4. `examples/locales/*.json` — all three JSON bundles (de-DE, ar-SA, ja-JP)

Showcase embeds locale JSON via `$embed_file`; no disk I/O at runtime.
`locale_registry.v` `init()` auto-registers 3 built-in presets.

## IME Integration

- IME overlay created lazily in `frame_fn` via `init_ime()` — NSWindow not
  ready during `init_fn`.
- `vglyph.ime_overlay_set_focused_field()` MUST be called to make overlay
  first responder; without it, no IME interception.
- `update_ime_focus` MUST only activate overlay for shapes with
  `on_ime_commit != nil`. Activating for menus/other focusables steals events,
  breaks hover/click.
- Timing: `set_id_focus` fires during `on_init` (layout gen) before `init_ime`
  runs. Fix: after overlay creation, re-apply focus if already set.
- Tab navigation: use `w.set_id_focus()`, not direct
  `w.view_state.id_focus = …` — `set_id_focus` triggers IME hooks.
- `keyDown:` forwards unhandled keys to MTKView; no double-insertion for ASCII.

Relevant files: `ime.v`, `window.v`, `view_input.v`, `view_container.v`,
`render_layout_tree.v`, `shape.v`, `xtra_window.v`, `view_text.v`.

## id_focus Allocation

`id_focus` is a `u32` that identifies focusable widgets. Composite
widgets consume multiple consecutive IDs from their base:

| Widget | IDs used |
|--------|----------|
| `color_picker` | base .. base+7 (SV area, RGBA, HSV channels) |
| `radio_button_group` | base .. base+N-1 (one per option) |
| `numeric_input` | 1 |
| `input` | 1 |
| `select` | 1 |

When placing multiple focusable widgets in the same view, space
`id_focus` values to avoid collisions. Overlapping IDs cause
unintended focus jumps (e.g. selecting a radio button activates a
color picker channel).

## Module Structure

```
gui/                  # main module — Window, View, Layout, Shape, Renderer
  svg/                # SVG parsing, tessellation, geometry (import svg)
  nativebridge/       # platform bridge (import nativebridge)
```

Files that need Window/View/Renderer stay in `gui/`: `svg_load.v`,
`render_svg.v`, `view_svg.v`, `svg_textpath.v`.

`SvgColor` in the submodule mirrors `gui.Color`; conversion via
`svg_to_color()` at the boundary in `svg_load.v` / `render_svg.v`.

Test files in `module svg` must not use `svg` as a local variable name
(shadows the module name).

## Draw Canvas

`DrawCanvasView` (`view_draw_canvas.v`) provides a retained-mode
drawing surface. The user supplies an `on_draw: fn (mut DrawContext)`
callback; `DrawContext` (`canvas_draw.v`) offers:

- `polyline`, `line` — stroked paths
- `filled_polygon`, `filled_rect`, `rect` — filled/stroked geometry
- `filled_circle`, `circle`, `arc`, `filled_arc` — circular primitives

All primitives tessellate to flat triangle batches emitted as `DrawSvg`
renderers. `StrokeCap` / `StrokeJoin` are re-exported from `svg` so
callers need not import it.

Tessellation is **cached** by widget `id + version` in a `state_map`.
Bump `version` to invalidate; unchanged canvases skip `on_draw`
entirely. If the canvas needs to redraw every frame, set `version`
to an incrementing counter.

```v ignore
gui.draw_canvas(
    id: 'chart'
    version: data_version
    width: 400
    height: 300
    on_draw: fn (mut dc gui.DrawContext) {
        dc.filled_rect(0, 0, dc.width, dc.height, bg_color)
        dc.polyline(pts, line_color, 2.0, .butt, .miter)
    }
)
```

## Animation System

Files: `animation.v`, `animation_tween.v`, `animation_spring.v`,
`animation_keyframe.v`, `animation_hero.v`, `animation_easing.v`,
`animation_loop.v`.

### Types

| Type | Duration | Key trait |
|------|----------|-----------|
| `TweenAnimation` | fixed (default 300ms) | easing curve, `from`/`to` |
| `SpringAnimation` | physics-based, settles | `SpringCfg` (stiffness, damping, mass) |
| `KeyframeAnimation` | fixed | multi-waypoint `[]Keyframe` |
| `HeroTransition` | fixed (default 300ms) | morphs `hero: true` elements |

### Spring presets

`spring_default` (100/10), `spring_gentle` (50/8),
`spring_bouncy` (300/15), `spring_stiff` (500/30).

### Loop

Animations run in a goroutine at 16 ms cycle. Each animation's
`refresh_kind()` determines the refresh path:

- `.layout` — full rebuild (state-mutating tweens, springs)
- `.render_only` — renderer rebuild only (cursor blink)

### Hero

Only one `HeroTransition` active at a time (fixed ID
`'__hero_transition__'`). Mark shapes with `hero: true` + matching
`id` across views. Hero snapshots the outgoing layout; the incoming
layout lerps position/size from the snapshot.

### API

```v ignore
w.animation_add(mut TweenAnimation{ id: 'x', from: 0, to: 1,
    on_value: fn [mut state] (v f32, mut w Window) { ... } })
w.has_animation('x')     // check active
w.remove_animation('x')  // cancel
```

## State Management (state_registry)

`state_registry.v` provides per-widget typed state maps keyed by
namespace string. Replaces dedicated fields on `ViewState`.

```v ignore
mut sm := gui.state_map[string, MyState](mut w, 'mylib.wgt', 20)
st := sm.get(id) or { MyState{} }
sm.set(id, new_st)
```

- `state_map[K, V](mut w, ns, max_size)` — get or create
- `state_map_read[K, V](w, ns)` — read-only, no `mut Window`
- Type-checked: same namespace must use matching `[K, V]` types
- Backed by `BoundedMap` with LRU eviction at `max_size`

### Capacity constants

`cap_few` (20), `cap_moderate` (50), `cap_many` (100),
`cap_scroll` (200), `cap_tree_focus` (30).

### Reserved namespaces

Internal namespaces start with `gui.` — e.g. `gui.input`,
`gui.scroll.x`, `gui.scroll.y`, `gui.select`, `gui.dock.drag`,
`gui.draw_canvas`. Third-party modules should use their own prefix.

## Event Handling & Command Queue

### EventHandlers

Allocated lazily on `Shape` via optional `&EventHandlers` pointer.
Check existence with `shape.has_events()`.

Key callbacks (all take `(&Layout, mut Event, mut Window)` unless
noted):

`on_click`, `on_hover`, `on_keydown`, `on_char`, `on_mouse_move`,
`on_mouse_up`, `on_mouse_scroll`.

Special: `on_scroll(&Layout, mut Window)` (no Event),
`on_ime_commit(&Layout, string, mut Window)`.

`amend_layout` runs during `layout_arrange`, not during rendering.

### Command queue

`queue_command(fn (mut Window))` — thread-safe callback for
cross-thread UI mutations. Executed by `flush_commands()` at frame
start. Preferred over direct `lock()`/`unlock()`.

### Mouse lock

`w.mouse_lock(MouseLockCfg{...})` redirects all mouse events to
specified handlers until `w.mouse_unlock()`. Used by splitter,
dock drag, range slider.

## Toast Notifications

`view_toast.v`. Non-blocking notifications with animated
enter/exit.

```v ignore
id := w.toast(gui.ToastCfg{
    title:    'Saved'
    severity: .success
    duration: 3 * time.second  // 0 = no auto-dismiss
})
w.toast_dismiss(id)       // manual dismiss
w.toast_dismiss_all()
```

Severity: `.info`, `.success`, `.warning`, `.error`.
Optional `action_label` + `on_action` callback.
Floating container anchored via `ToastStyle.anchor` in theme.
Max visible toasts enforced; excess are auto-dismissed.

## Scroll API

```v ignore
w.scroll_vertical_to_pct(id_scroll, 0.5)   // 50% down
w.scroll_horizontal_to_pct(id_scroll, 0.0)  // left edge
pct := w.scroll_vertical_pct(id_scroll)     // query position
w.scroll_to_view('my_element_id')           // reveal element
```

`pct` range: 0.0 (start) to 1.0 (end). Clamped. No-op if content
fits viewport. Scroll offsets are stored as negative values
internally (top-anchored layout).

## Floating Elements

`layout_float.v`. Any shape with `float: true` is removed from
normal layout flow and positioned relative to its parent via
anchor points.

| Field | Type | Purpose |
|-------|------|---------|
| `float` | `bool` | enable floating |
| `float_anchor` | `FloatAttach` | anchor on parent |
| `float_tie_off` | `FloatAttach` | anchor on self |
| `float_offset_x/y` | `f32` | pixel offset from anchor |

`FloatAttach` enum: `top_left`, `top_center`, `top_right`,
`middle_left`, `middle_center`, `middle_right`, `bottom_left`,
`bottom_center`, `bottom_right`.

RTL mirroring swaps left/right via `mirror_float_attach`.

## Dock Layout System

Files: `dock_layout_tree.v`, `view_dock_layout.v`,
`dock_layout_drag.v`.

IDE-style docking panels. Binary tree of splits; leaves are
panel groups (tabs).

### DockNode

Tagged struct (not sumtype — avoids V dangling pointer bug).
`kind: .split | .panel_group`. Constructors:

```v ignore
dock_split(id, dir, ratio, first, second)  // -> &DockNode
dock_panel_group(id, panel_ids, selected)  // -> &DockNode
```

Tree is **immutable** — mutations return new trees via pure
functions (`dock_insert`, `dock_remove`, `dock_move`, etc.).

### View integration

`DockLayoutView implements View` — provides `mut Window` access in
`generate_layout`. `DockLayoutCore` is the GC-safe closure capture
struct (like `SplitterCore`). Drag state stored under
`ns_dock_drag` in `state_registry`.

## Testing Conventions

- Test files named `_*_test.v` (underscore prefix per CLAUDE.md
  global instructions).
- Guard-clause tests: verify early returns for invalid input
  (e.g. `test_polyline_rejects_too_few_points`).
- Tests organized by feature file: `_draw_canvas_test.v`,
  `_bounded_map_test.v`, `_view_splitter_test.v`,
  `_view_table_test.v`, etc.
- Run: `v test .` from the `gui/` directory.

## Component Index

### Layout containers

`view_container.v` (row/column), `view_splitter.v`,
`view_dock_layout.v`, `view_sidebar.v`, `view_tab_control.v`,
`view_expand_panel.v`, `view_overflow_panel.v`.

### Input widgets

`view_input.v`, `view_numeric_input.v`, `view_input_date.v`,
`view_select.v`, `view_combobox.v`, `view_command_palette.v`,
`view_date_picker.v`, `view_date_picker_roller.v`,
`view_color_picker.v`, `view_range_slider.v`.

### Display widgets

`view_text.v`, `view_rtf.v`, `view_markdown.v`, `view_image.v`,
`view_svg.v`, `view_badge.v`, `view_progress_bar.v`,
`view_pulsar.v`, `view_rectangle.v`, `view_draw_canvas.v`.

### Interactive controls

`view_button.v`, `view_toggle.v`, `view_switch.v`, `view_radio.v`,
`view_radio_button_group.v`, `view_breadcrumb.v`, `view_link_context_menu.v`,
`view_theme_toggle.v`.

### Data views

`view_table.v`, `view_data_grid.v` (+ `_columns`, `_crud`,
`_events`, `_export`, `_header`, `_rows`), `view_tree.v`,
`view_listbox.v`.

### Overlay / feedback

`view_dialog.v`, `view_toast.v`, `view_tooltip.v`, `view_menu.v`,
`view_menu_item.v`, `view_menubar.v`, `view_scrollbar.v`,
`view_form.v`.
