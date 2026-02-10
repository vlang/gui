# Native Dialogs

This guide covers native path dialogs:
- `native_open_dialog`
- `native_save_dialog`
- `native_folder_dialog`

## Platform Behavior

- macOS: uses native AppKit dialogs.
- Linux: uses `zenity` (`--file-selection` modes).
- other platforms: callback runs, returns `.error` with `error_code == 'unsupported'`.

Linux notes:
- requires `zenity` in `PATH`.
- if `zenity` is missing, callback returns `.error` with `error_code == 'unsupported'`.
- if display/session launch fails, callback returns `.error` with `error_code == 'internal'`.

## Result Model

`on_done` receives `NativeDialogResult`:

| Field | Meaning |
|---|---|
| `status` | `.ok`, `.cancel`, `.error` |
| `paths` | selected paths. empty on cancel/error |
| `error_code` | machine code (`unsupported`, `invalid_cfg`, etc.) |
| `error_message` | human readable detail |

Notes:
- callback runs on main thread.
- callback is deferred via command queue, not inline in mouse event handler.

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
- if `confirm_overwrite == false` and file exists, returns `.error`.

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
			w.dialog(title: kind, body: result.paths.join('\n'))
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

Invalid extension chars return `.error` with `error_code == 'invalid_cfg'`.
Valid chars: `a-z`, `0-9`, `_`, `-`, `+`.

## Full Working Demo

See `examples/dialogs.v`.
