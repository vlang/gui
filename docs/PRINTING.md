# Printing

This guide covers:
- `export_pdf`
- `native_print_dialog`

## Platform Behavior

- macOS: uses native print panel.
- Linux: opens PDF in default app (`xdg-open`/`gio`) for user-initiated print dialog.
- other platforms: callback runs and returns `.error` with `error_code == 'unsupported'`.

Linux notes:
- prefers `xdg-open`, then `gio open` to launch the PDF.
- falls back to direct `lp` dispatch only if openers are unavailable.
- with opener path, callback returns `.cancel` because user print/cancel outcome is not observable.
- callback `.ok` currently means direct dispatch succeeded (`lp` fallback path).

## Export PDF

`export_pdf` exports current renderers to single-page PDF.

```v ignore
result := w.export_pdf(
	path:        '/tmp/report.pdf'
	paper:       .letter
	orientation: .portrait
	margins:     gui.PrintMargins{
		top:    36
		right:  36
		bottom: 36
		left:   36
	}
)

if !result.is_ok() {
	eprintln('${result.error_code}: ${result.error_message}')
}
```

## Native Print Dialog

Print current view (exports temporary PDF first):

```v ignore
w.native_print_dialog(
	title:       'Print'
	job_name:    'Monthly Report'
	paper:       .a4
	orientation: .portrait
	content:     gui.NativePrintContent{
		kind: .current_view_pdf
	}
	on_done:     fn (result gui.NativePrintResult, mut w gui.Window) {
		match result.status {
			.ok { w.dialog(title: 'Printed', body: result.pdf_path) }
			.cancel { w.dialog(title: 'Print', body: 'Canceled.') }
			.error { w.dialog(title: 'Print', body: '${result.error_code}: ${result.error_message}') }
		}
	}
)
```

Print an existing PDF path:

```v ignore
w.native_print_dialog(
	title:   'Print Existing PDF'
	content: gui.NativePrintContent{
		kind:     .prepared_pdf_path
		pdf_path: '/tmp/report.pdf'
	}
	on_done: fn (result gui.NativePrintResult, mut w gui.Window) {
		// handle result
	}
)
```

## Result Model

`on_done` receives `NativePrintResult`:

| Field | Meaning |
|---|---|
| `status` | `.ok`, `.cancel`, `.error` |
| `error_code` | machine code (`unsupported`, `invalid_cfg`, `io_error`, `render_error`) |
| `error_message` | human-readable detail |
| `pdf_path` | generated/printed PDF path when status is `.ok` |
