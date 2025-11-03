  --------------------
  # 11 Expand Panel
  --------------------

An expand panel is a collapsible container that can show or hide its
content. It consists of a clickable header (which always displays) and a
content area (which toggles visibility based on the `open` state). The
header displays an arrow icon that indicates the current state:
`icon_arrow_up` when open, `icon_arrow_down` when closed.

See also: `examples/expand_panel.v` for a runnable showcase.

## Overview

`expand_panel` creates a container with two parts:

- **Header** (`head`): A clickable row that contains custom content and
  an arrow indicator. Clicking the header toggles the panel's open
  state.
- **Content** (`content`): A collapsible column that shows or hides
  based on the `open` boolean.

The expand panel is built from nested containers with separate styling
for the border and interior, similar to buttons. The header has hover
effects (cursor changes to pointing hand, background color changes on
hover).

## ExpandPanelCfg

The `expand_panel` view is created with an `ExpandPanelCfg` structure.
Important fields:

- `id string` --- Optional identifier for the view.
- `head View` --- The header content (required). This is a view that
  appears in the clickable header row. The arrow icon is automatically
  added to the right side.
- `content View` --- The collapsible content (required). This view is
  shown when `open: true` and hidden when `open: false`.
- `open bool` --- Controls whether the panel is expanded (`true`) or
  collapsed (`false`).
- `on_toggle fn (mut Window)` --- Callback invoked when the header is
  clicked. Use this to update your state (typically toggle the `open`
  field in your app state).
- Colors
  - `color` --- Interior color (defaults to theme's
    `expand_panel_style.color`)
  - `color_border` --- Border color (defaults to theme's
    `expand_panel_style.color_border`)
- Padding and radius
  - `padding Padding` --- Interior padding (defaults to theme's
    `expand_panel_style.padding`)
  - `padding_border Padding` --- Border padding (defaults to theme's
    `expand_panel_style.padding_border`)
  - `radius f32` --- Corner radius for interior (defaults to theme's
    `expand_panel_style.radius`)
  - `radius_border f32` --- Corner radius for border (defaults to
    theme's `expand_panel_style.radius_border`)
- Sizing and layout
  - `sizing Sizing` --- Standard sizing (`fit`, `fill`, `fixed`,
    combinations)
  - `min_width`, `max_width`, `min_height`, `max_height f32` --- Size
    constraints
  - `fill bool` --- Fill interior rectangle (defaults to theme's
    `expand_panel_style.fill`)
  - `fill_border bool` --- Fill border rectangle (defaults to theme's
    `expand_panel_style.fill_border`)

## Interaction model

- **Click**: Clicking anywhere in the header row triggers `on_toggle` if
  provided.
- **Hover**: When the pointer is over the header, the mouse cursor
  changes to a pointing hand and the header background uses
  `gui_theme.color_hover`.
- **Arrow indicator**: The header automatically shows `icon_arrow_up`
  when `open: true` and `icon_arrow_down` when `open: false`.

## Basic example

A simple expand panel that toggles when clicked:

``` v
import gui

struct App {
    mut:
        panel_open bool
}

fn main() {
    mut window := gui.window(
        title:   'Expand Panel Demo'
        state:   &App{}
        width:   400
        height:  300
        on_init: fn (mut w gui.Window) {
            w.update_view(main_view)
        }
    )
    window.run()
}

fn main_view(mut w gui.Window) gui.View {
    mut app := w.state[App]()
    
    return gui.column(
        padding: gui.theme().padding_medium
        content: [
            gui.expand_panel(
                open: app.panel_open
                head: gui.row(
                    padding: gui.theme().padding_medium
                    content: [gui.text(text: 'Click to expand')]
                )
                content: gui.column(
                    padding: gui.theme().padding_medium
                    content: [
                        gui.text(text: 'This is the hidden content.'),
                        gui.text(text: 'It appears when the panel is open.'),
                    ]
                )
                on_toggle: fn (mut win gui.Window) {
                    mut app := win.state[App]()
                    app.panel_open = !app.panel_open
                }
            ),
        ]
    )
}
```

## Multiple panels with auto-close

A common pattern is to have multiple expand panels where opening one
closes the others:

``` v
struct App {
    mut:
        open_titles []string
        auto_close  bool
}

fn expander(title string, description string, mut app App) gui.View {
    return gui.expand_panel(
        open: title in app.open_titles
        sizing: gui.fill_fit
        head: gui.row(
            padding: gui.theme().padding_medium
            content: [gui.text(text: title)]
        )
        content: gui.column(
            padding: gui.theme().padding_medium
            content: [
                gui.text(text: description, mode: .wrap),
            ]
        )
        on_toggle: fn [title] (mut w gui.Window) {
            mut app := w.state[App]()
            if app.auto_close {
                // Close all others, open only this one
                match title in app.open_titles {
                    true { app.open_titles.clear() }
                    else { app.open_titles = [title] }
                }
            } else {
                // Toggle this one independently
                match title in app.open_titles {
                    true { app.open_titles = app.open_titles.filter(it != title) }
                    else { app.open_titles << title }
                }
            }
        }
    )
}
```

## Custom header content

The header can contain any views. Here's an example with multiple
elements:

``` v
gui.expand_panel(
    open: app.is_open
    head: gui.row(
        padding: gui.theme().padding_medium
        sizing: gui.fill_fit
        v_align: .middle
        content: [
            gui.text(text: 'Section Title', text_style: gui.theme().n3),
            gui.row(sizing: gui.fill_fit), // Spacer
            gui.text(text: 'Subtitle', text_style: gui.theme().n4),
        ]
    )
    content: gui.column(
        content: [/* your content */]
    )
    on_toggle: fn (mut w gui.Window) { /* ... */ }
)
```

The arrow icon is automatically added to the right side of the header,
so you don't need to include it in your `head` view.

## Styling

Expand panels use theme defaults, but you can override colors, padding,
and radius:

``` v
gui.expand_panel(
    open: app.open
    color: gui.rgb(240, 240, 240)
    color_border: gui.rgb(200, 200, 200)
    padding: gui.padding_medium
    padding_border: gui.padding_small
    radius: 8
    radius_border: 10
    head: gui.row(/* ... */)
    content: gui.column(/* ... */)
    on_toggle: fn (mut w gui.Window) { /* ... */ }
)
```

## Tips

- Store the `open` state in your app state and update it in `on_toggle`.
- The header is always visible and clickable; only the content area
  toggles.
- Use `invisible: !cfg.open` internally; the content container is hidden
  when closed, so it doesn't take up space.
- For accordion-style behavior (only one panel open at a time), maintain
  a list of open panel IDs and clear/update it in `on_toggle`.
- The arrow icon automatically switches between `icon_arrow_up` (open)
  and `icon_arrow_down` (closed) based on the `open` field.

## See also

- `03-Views.md` --- background on views, containers, and sizing
- `07-Buttons.md` --- similar styling patterns (border/interior)
- `08-Container-View.md` --- understanding the underlying container
  structure
- `examples/expand_panel.v` --- comprehensive runnable examples
