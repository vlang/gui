# 10 Dialogs

`view_dialog.v` implements modal dialogs in GUI. Dialogs are rendered as
floating overlay views centered in the window and temporarily restrict
keyboard and mouse input to the dialog while it is visible.

This document covers:

- What dialog types exist (`DialogType`)
- How to configure dialogs (`DialogCfg`)
- Built-in button layouts and callbacks
- Prompt reply handling
- Keyboard behavior and focus
- Custom dialogs with arbitrary content
- Practical examples

See also:

- 03-Views.md --- how views are composed
- 05-Themes-Styles.md --- colors, radius, paddings used by defaults
- 08-Container-View.md --- containers used to compose the dialog content
- 09-Date-Picker.md --- another modal-like control for date selection
- `examples/dialogs.v` --- live usage examples

## Overview

Dialogs are asynchronous overlays you show by calling
`Window.dialog(cfg)` with a `DialogCfg`. While visible, focus and input
are constrained to the shown dialog. Dismissing the dialog restores the
previous focus.

Limitations and notes:

- Dialogs do not support floating elements inside their content
  (tooltips, etc.)
- Body text wraps automatically; newline characters are respected
- Ctrl-C copies the title and body to the clipboard for predefined types
- Use `Window.dialog_dismiss()` to close a custom dialog without
  invoking predefined callbacks

## DialogType

The `DialogType` enum selects the kind of dialog to present:

- `message` --- Title, body, and a single OK button
- `confirm` --- Title, body, Yes and No buttons
- `prompt` --- Title, body, an input field, and OK / Cancel buttons
- `custom` --- Full control: provide your own `[]View` content; standard
  callbacks are not automatically wired for this type

Future placeholders (not yet implemented): browse, save, color, date,
time.

## DialogCfg

`DialogCfg` configures the visual style, content, and behavior of a
dialog. Only the most relevant fields are shown here. See
`view_dialog.v` for the complete definition and defaults from
`gui_theme.dialog_style`.

Visual and layout:

- `title string` --- dialog title text
- `body string` --- main body text (wraps; supports newlines)
- `width f32`, `height f32` --- optional fixed size
- `min_width f32 = 200`, `max_width f32 = 300` --- horizontal limits
- `min_height f32`, `max_height f32` --- vertical limits
- `padding Padding` --- inner padding of the dialog face
- `padding_border Padding` --- padding of the border container
- `color Color`, `fill bool` --- face outline/fill
- `color_border Color`, `fill_border bool` --- border outline/fill
- `radius f32`, `radius_border f32` --- corner radii
- `title_text_style TextStyle`, `text_style TextStyle` --- text styles
- `align_buttons HorizontalAlign` --- alignment of predefined buttons
  (`.start`, `.center`, `.end`)

Behavior and composition:

- `dialog_type DialogType` --- one of
  `message | confirm | prompt | custom`
- `custom_content []View` --- content to render for `custom` dialogs
- `id_focus u32` --- focus group id used while dialog is active
- `id string` --- optional name/identifier for the dialog view

Callbacks:

- `on_ok_yes fn (mut Window)` --- called by OK (message/prompt) or Yes
  (confirm)
- `on_cancel_no fn (mut Window)` --- called by Cancel (prompt) or No
  (confirm)
- `on_reply fn (string, mut Window)` --- prompt content is passed as
  `reply`

Notes:

- For `custom` dialogs you are responsible for adding any buttons and
  calling `w.dialog_dismiss()` yourself when appropriate.

## Usage

### Message

``` v
w.dialog(
    dialog_type: .message
    title: 'Operation Complete'
    body: 'All tasks finished successfully.'
    align_buttons: .end
    on_ok_yes: fn (mut w gui.Window) {
        // optional follow-up action
    }
)
```

### Confirm

``` v
w.dialog(
    dialog_type: .confirm
    title: 'Delete File?'
    body: 'This action cannot be undone.'
    on_ok_yes: fn (mut w gui.Window) {
        w.dialog(title: 'Clicked Yes')
    }
    on_cancel_no: fn (mut w gui.Window) {
        w.dialog(title: 'Clicked No')
    }
)
```

### Prompt

``` v
w.dialog(
    dialog_type: .prompt
    title: 'Monty Python Quiz'
    body: 'What is your quest?'
    on_reply: fn (reply string, mut w gui.Window) {
        w.dialog(title: 'Replied', body: reply)
    }
    on_cancel_no: fn (mut w gui.Window) {
        w.dialog(title: 'Canceled')
    }
)
```

### Custom

Provide arbitrary content and dismiss programmatically.

``` v
w.dialog(
    dialog_type: .custom
    custom_content: [
        gui.column(
            h_align: .center
            v_align: .middle
            content: [
                gui.text(text: 'Custom Content')
                gui.button(
                    // Using the base dialog id focus makes Enter/Space work naturally
                    id_focus: gui.dialog_base_id_focus
                    content: [gui.text(text: 'Close Me')]
                    on_click: fn (_ &gui.ButtonCfg, mut _ gui.Event, mut w gui.Window) {
                        w.dialog_dismiss()
                    }
                )
            ]
        ),
    ]
)
```

## Keyboard and Focus

- The dialog captures focus while visible; the previous focus is
  restored on dismissal
- Enter activates the primary action (OK/Yes) where applicable
- Escape activates Cancel/No for confirm/prompt
- Ctrl-C copies title and body to the clipboard for predefined types

## API Reference

### Window.dialog

Creates and shows a dialog:

``` v
pub fn (mut window Window) dialog(cfg DialogCfg)
```

- Sets `window.dialog_cfg = cfg`
- Marks the dialog `visible`
- Saves the previous `id_focus` and sets `cfg.id_focus`

### Window.dialog_dismiss

Dismisses the current dialog without invoking callbacks. Useful for
`custom` dialogs.

``` v
pub fn (mut window Window) dialog_dismiss()
```

### Window.dialog_is_visible

Returns whether a dialog is currently visible.

``` v
pub fn (mut window Window) dialog_is_visible() bool
```

## Examples

See `examples/dialogs.v` for a compact showcase of `message`, `confirm`,
`prompt`, and `custom` dialogs, as well as theme switching for visual
style.
