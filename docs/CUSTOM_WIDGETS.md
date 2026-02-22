# Custom Widgets

Two approaches exist for building custom widgets: **composition**
(preferred) and **direct View implementation**. Composition assembles
existing primitives (`row`, `column`, `text`, `button`, etc.) via a
factory function. Direct implementation provides full control over
layout generation when composition falls short.

Both approaches follow the same cfg-struct + factory-function pattern
used throughout v-gui.

## Composition

Compose widgets from existing containers and primitives. This is the
same pattern used by `toggle`, `switch`, `radio_button`, and most
built-in widgets.

### Example: Star Rating

```v ignore
import gui

@[minify]
pub struct StarRatingCfg {
pub:
    value     int
    max       int                                     = 5
    on_change fn (int, &gui.Layout, mut gui.Window)   = unsafe { nil }
    size      gui.TextStyle                           = gui.theme().m5
}

pub fn star_rating(cfg StarRatingCfg) gui.View {
    max := cfg.max
    on_change := cfg.on_change
    size := cfg.size

    mut stars := []gui.View{cap: max}
    for i in 0 .. max {
        filled := i < cfg.value
        symbol := if filled { '\u2605' } else { '\u2606' }
        idx := i + 1
        stars << gui.text(
            text:       symbol
            text_style: size
            on_click:   fn [idx, on_change] (
                l &gui.Layout, mut _ gui.Event, mut w gui.Window,
            ) {
                if on_change != unsafe { nil } {
                    on_change(idx, l, mut w)
                }
            }
            on_hover:   fn (mut _ gui.Layout, mut _ gui.Event,
                mut w gui.Window,
            ) {
                w.set_mouse_cursor_pointing_hand()
            }
        )
    }
    return gui.row(spacing: 2, content: stars)
}
```

Key points:

- `@[minify]` reduces struct size — always use it on cfg structs.
- The factory function (`star_rating`) returns `gui.View`, not a
  concrete type. Callers never see the internal layout.
- Closure captures extract only the fields needed (`max`,
  `on_change`, `size`, `idx`). Never capture the entire cfg struct.
  See [Event Handling](#event-handling) below.

### Usage

```v ignore
gui.column(
    content: [
        star_rating(StarRatingCfg{
            value:     app.rating
            on_change: fn (val int, _ &gui.Layout, mut w gui.Window) {
                mut app := w.state[App]()
                app.rating = val
            }
        }),
    ]
)
```

## Direct View Implementation

Implement the `View` interface when composition is insufficient —
custom layout logic, non-rectangular hit regions, direct shape
construction, etc.

### Example: Badge

```v ignore
import gui

@[minify]
struct BadgeView implements gui.View {
    BadgeCfg
mut:
    content []gui.View // required by View interface, unused here
}

@[minify]
pub struct BadgeCfg {
pub:
    label string
    color gui.Color = gui.theme().color_active
}

pub fn badge(cfg BadgeCfg) gui.View {
    return BadgeView{BadgeCfg: cfg}
}

fn (mut bv BadgeView) generate_layout(mut w gui.Window) gui.Layout {
    ts := gui.TextStyle{
        ...gui.theme().m4
        color: gui.Color{255, 255, 255, 255}
    }
    return gui.Layout{
        shape: &gui.Shape{
            shape_type: .rectangle
            color:      bv.color
            radius:     10
            padding:    gui.Padding{3, 8, 3, 8}
        }
        children: [
            gui.Layout{
                shape: &gui.Shape{
                    shape_type: .text
                    tc:         &gui.TextConfig{
                        text:       bv.label
                        text_style: ts
                    }
                }
            },
        ]
    }
}
```

The struct must:

1. Have `implements gui.View` in its declaration.
2. Embed the cfg struct or replicate its fields.
3. Declare `content []gui.View` (the interface requires it even if
   unused).
4. Implement `generate_layout(mut Window) Layout`.

Reference implementations: `view_image.v` (ImageView),
`view_svg.v` (SvgView).

## Event Handling

Attach callbacks via shape fields: `on_click`, `on_hover`,
`on_char`, `on_key_down`, `on_mouse_move`, and `amend_layout`.

### Closure Capture Rule

V uses the Boehm conservative GC. Closures that capture an entire
`@[heap]` struct keep every pointer-sized field alive — causing
false retention. **Always extract only the fields the closure
needs into locals, then capture those locals.**

```v ignore
// Bad — captures entire cfg:
on_click: fn [cfg] (l &gui.Layout, mut e gui.Event,
    mut w gui.Window,
) {
    cfg.callback(l, mut w)
}

// Good — extract minimal fields:
callback := cfg.callback
on_click: fn [callback] (l &gui.Layout, mut e gui.Event,
    mut w gui.Window,
) {
    callback(l, mut w)
}
```

See `view_toggle.v`, `view_select.v`, and `view_menubar.v` for
real-world extraction patterns.

### amend\_layout

`amend_layout` runs during the layout-arrange pass (after sizing,
before positioning). Use it for focus styling, conditional
visibility, or geometry adjustments:

```v ignore
gui.row(
    amend_layout: fn [color_focus] (mut layout gui.Layout,
        mut w gui.Window,
    ) {
        if w.is_focus(layout.shape.id_focus) {
            layout.shape.color = color_focus
        }
    }
    content: [...]
)
```

## Theming

Read the current theme via `gui.theme()`. Accept style overrides in
the cfg struct with theme defaults:

```v ignore
@[minify]
pub struct MyCfg {
pub:
    color      gui.Color     = gui.theme().color_active
    text_style gui.TextStyle = gui.theme().m5
    padding    gui.Padding   = gui.theme().padding
}
```

This lets callers override individual properties while inheriting
the active theme for everything else.

## State Management

v-gui is immediate-mode: widgets are stateless pure functions of
their configuration. There is no widget instance that persists
between frames.

Application state lives in a `@[heap]` struct accessed via
`w.state[T]()`:

```v ignore
@[heap]
struct App {
pub mut:
    rating int = 3
}

// Read state in view function:
app := window.state[App]()

// Mutate state in callbacks:
on_click: fn (_ &gui.Layout, mut _ gui.Event,
    mut w gui.Window,
) {
    mut app := w.state[App]()
    app.rating += 1
}
```

After mutating state, v-gui automatically triggers a full layout
rebuild. Call `w.update_window()` explicitly only when state changes
outside of event handlers.

### Per-Widget State with StateRegistry

`w.state[T]()` is for global application state. When a widget needs
its own internal state keyed by instance id — open/closed flags,
scroll offsets, animation progress — use the `StateRegistry` via
three public functions:

| Function | Requires | Purpose |
|----------|----------|---------|
| `state_map[K,V](mut w, ns, cap)` | `mut Window` | get or create map (read/write) |
| `state_map_read[K,V](w, ns)` | `&Window` | read-only; returns `none` if uninitialized |
| `state_read_or[K,V](w, ns, key, default)` | `&Window` | read one value with fallback |

`state_map` lazily creates a `&BoundedMap[K, V]` for the given
namespace. The third argument sets the LRU eviction cap — use one
of the built-in tiers:

| Constant | Max entries | Typical use |
|----------|-------------|-------------|
| `cap_few` | 20 | menus, pickers |
| `cap_moderate` | 50 | general widgets |
| `cap_many` | 100 | inputs, focus tracking |
| `cap_scroll` | 200 | scroll containers |

Write state in callbacks (which receive `mut Window`):

```v ignore
mut sm := gui.state_map[string, bool](
    mut w, 'myapp.collapsible', gui.cap_moderate,
)
sm.set(id, !cur)
```

Read state in view functions (which receive `&Window`):

```v ignore
is_open := gui.state_read_or[string, bool](
    window, 'myapp.collapsible', id, true,
)
```

#### Example: Collapsible Section

A composition widget that remembers open/closed state across
frames. The view function reads state via `state_read_or`; the
click handler writes via `state_map`:

```v ignore
import gui

@[minify]
pub struct CollapsibleCfg {
pub:
    id      string @[required]
    title   string
    open    bool   = true
    content []gui.View
}

pub fn collapsible(window &gui.Window, cfg CollapsibleCfg) gui.View {
    id := cfg.id
    open := cfg.open
    is_open := gui.state_read_or[string, bool](
        window, 'myapp.collapsible', id, open,
    )
    arrow := if is_open { '\u25BC' } else { '\u25B6' }

    mut views := []gui.View{cap: 2}
    views << gui.row(
        on_click: fn [id, open] (_ &gui.Layout,
            mut _ gui.Event, mut w gui.Window,
        ) {
            mut sm := gui.state_map[string, bool](
                mut w, 'myapp.collapsible',
                gui.cap_moderate,
            )
            cur := sm.get(id) or { open }
            sm.set(id, !cur)
        }
        on_hover: fn (mut _ gui.Layout, mut _ gui.Event,
            mut w gui.Window,
        ) {
            w.set_mouse_cursor_pointing_hand()
        }
        content: [gui.text(text: '${arrow} ${cfg.title}')]
    )
    if is_open {
        views << gui.column(content: cfg.content)
    }
    return gui.column(content: views)
}
```

Called from a view function where `&Window` is available:

```v ignore
fn main_view(window &gui.Window) gui.View {
    return collapsible(window, CollapsibleCfg{
        id:      'section1'
        title:   'Details'
        content: [gui.text(text: 'Body content here.')]
    })
}
```

Use a unique namespace string (e.g. `'mylib.widget'`) to avoid
collisions with other widgets or internal gui state.

## Guidelines

- Prefer composition over direct View implementation.
- Use `@[minify]` on all cfg structs.
- Provide a factory function returning `gui.View`.
- Extract closure captures to local variables — never capture the
  entire cfg struct.
- Read `gui.theme()` for default colors, padding, and text styles.
- Keep widgets stateless. App state belongs in `w.state[T]()`.
- For accessibility, set `a11y_role`, `a11y_label`, and
  `a11y_state` on the outermost container.
- Use `spacebar_to_click` and `left_click_only` wrappers for
  keyboard-accessible click targets (see `view_toggle.v`).
