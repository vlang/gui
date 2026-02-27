# Native Dialogs

This guide covers native dialogs:
- `native_open_dialog` — file picker
- `native_save_dialog` — save-as picker
- `native_folder_dialog` — folder picker
- `native_message_dialog` — OS alert/message box
- `native_confirm_dialog` — OS yes/no confirmation

## Platform Behavior

- macOS: native AppKit dialogs with security-scoped bookmark
  support for sandboxed apps.
- Linux: XDG Desktop Portal via D-Bus (preferred), falling
  back to `zenity` or `kdialog`.
- Windows: returns `.error` with
  `error_code == 'unsupported'`. Not yet implemented.

Linux notes:
- portal mode requires `org.freedesktop.portal.Desktop` on
  session bus (standard in Flatpak/Snap and most desktops).
- if portal is unavailable, falls back to `zenity`/`kdialog`.
- if all are missing, callback returns `.error` with
  `error_code == 'unsupported'`.

## Result Model

`on_done` receives `NativeDialogResult`:

| Field | Meaning |
|---|---|
| `status` | `.ok`, `.cancel`, `.error` |
| `paths` | `[]AccessiblePath` — path + grant. empty on cancel/error |
| `error_code` | machine code (`unsupported`, `invalid_cfg`, etc.) |
| `error_message` | human readable detail |

### AccessiblePath

Each path returned from a dialog is wrapped in
`AccessiblePath`:

```v ignore
pub struct AccessiblePath {
pub:
    path  string
    grant Grant
}
```

`Grant` identifies a security-scoped bookmark. On macOS
sandboxed apps the grant keeps the file accessible across
relaunches. On Linux and Windows the grant id is 0 (no-op).

### Convenience: path_strings()

For code that does not need sandbox persistence:

```v ignore
paths := result.path_strings()  // []string
```

### Migration from []string paths

Old code:

```v ignore
file := result.paths[0]
```

New code:

```v ignore
file := result.paths[0].path
```

Or for joining:

```v ignore
result.path_strings().join('\n')
```

Notes:
- callback runs on main thread.
- callback is deferred via command queue, not inline in mouse
  event handler.

## Sandbox Persistence (macOS)

### Setup

Set `app_id` in `WindowCfg` and call `restore_file_access()`
in `on_init`:

```v ignore
gui.window(gui.WindowCfg{
    app_id:  'com.example.myapp'
    on_init: fn (mut w gui.Window) {
        w.restore_file_access()
        w.update_view(my_view)
    }
})
```

### Lifecycle

1. User picks a file via `native_open_dialog` /
   `native_save_dialog` / `native_folder_dialog`.
2. Framework creates a security-scoped bookmark and stores it
   in `NSUserDefaults` keyed by `app_id`.
3. `AccessiblePath.grant` holds the live grant.
4. On next launch, `restore_file_access()` reloads and
   activates all persisted bookmarks.
5. Call `release_file_access(grant)` to release a single
   grant, or `release_all_file_access()` to release all.
   `release_all_file_access()` is called automatically on
   window cleanup.

### Without app_id

If `app_id` is empty (default), bookmarks are not persisted
to disk. Grants are still tracked in memory and released on
cleanup. Non-sandboxed apps work identically to before.

## Open File Dialog

Use for single or multi-select.

```v ignore
w.native_open_dialog(
    title:          'Open Files'
    allow_multiple: true
    filters:        [
        gui.NativeFileFilter{
            name:       'Images'
            extensions: ['png', 'jpg', 'jpeg']
        },
        gui.NativeFileFilter{
            name:       'Docs'
            extensions: ['txt', 'md']
        },
    ]
    on_done:        fn (result gui.NativeDialogResult, mut w gui.Window) {
        handle_native_result('open', result, mut w)
    }
)
```

## Save As Dialog

`native_save_dialog` is Save As.

```v ignore
w.native_save_dialog(
    title:             'Save As'
    default_name:      'untitled'
    default_extension: 'txt'
    confirm_overwrite: true
    filters:           [
        gui.NativeFileFilter{
            name:       'Text'
            extensions: ['txt']
        },
    ]
    on_done:           fn (result gui.NativeDialogResult, mut w gui.Window) {
        handle_native_result('save', result, mut w)
    }
)
```

Behavior:
- if user omits extension, default extension is appended.
- if `confirm_overwrite == false` and file exists, returns
  `.error`.

## Folder Dialog

```v ignore
w.native_folder_dialog(
    title:                  'Choose Folder'
    can_create_directories: true
    on_done:                fn (result gui.NativeDialogResult, mut w gui.Window) {
        handle_native_result('folder', result, mut w)
    }
)
```

## Common Result Handler

```v ignore
fn handle_native_result(kind string, result gui.NativeDialogResult, mut w gui.Window) {
    match result.status {
        .ok {
            w.dialog(title: kind, body: result.path_strings().join('\n'))
        }
        .cancel {
            w.dialog(title: kind, body: 'Canceled.')
        }
        .error {
            w.dialog(title: kind, body: '${result.error_code}: ${result.error_message}')
        }
    }
}
```

## Filter Rules

Filter extensions are normalized before native call:
- lowercased
- leading dots removed
- duplicates removed
- empty entries ignored

Invalid extension chars return `.error` with
`error_code == 'invalid_cfg'`.
Valid chars: `a-z`, `0-9`, `_`, `-`, `+`.

## Message Dialog

`native_message_dialog` shows a native OS alert with an OK
button. The `level` controls the severity icon.

```v ignore
w.native_message_dialog(
    title:   'Operation Complete'
    body:    'All files have been saved.'
    level:   .info
    on_done: fn (result gui.NativeAlertResult, mut w gui.Window) {
        // result.status is always .ok for message dialogs
    }
)
```

## Confirm Dialog

`native_confirm_dialog` shows a native OS dialog with Yes/No
buttons.

```v ignore
w.native_confirm_dialog(
    title:   'Delete File?'
    body:    'This action cannot be undone.'
    level:   .warning
    on_done: fn (result gui.NativeAlertResult, mut w gui.Window) {
        if result.status == .ok {
            // user clicked Yes
        }
    }
)
```

## NativeAlertLevel

| Value | macOS | Windows | Linux |
|---|---|---|---|
| `.info` | informational icon | `MB_ICONINFORMATION` | `--info` |
| `.warning` | warning icon | `MB_ICONWARNING` | `--warning` |
| `.critical` | critical icon | `MB_ICONERROR` | `--error` |

## NativeAlertResult

| Field | Meaning |
|---|---|
| `status` | `.ok` (Yes/OK), `.cancel` (No), `.error` |
| `error_code` | machine code on error |
| `error_message` | human readable detail on error |

## Full Working Demo

See `examples/dialogs.v`.
