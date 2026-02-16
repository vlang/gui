# Printing

This guide covers:
- `export_print_job`
- `run_print_job`

## Platform behavior

- macOS: uses native print panel.
- Linux: prefers opener (`xdg-open` / `gio open`), falls back to `lp` direct dispatch.
- other platforms: returns `.error` with `error_code == 'unsupported'`.

Linux notes:
- opener path cannot guarantee copies/ranges/duplex/color; warnings are returned.
- direct `lp` path applies supported options (`copies`, `page_ranges`, `duplex`, `color`).

## Export PDF

`export_print_job` exports current renderers to PDF.

```v ignore
result := w.export_print_job(gui.PrintJob{
    output_path: "/tmp/report.pdf"
    title:       "Monthly Report"
    paper:       .letter
    orientation: .portrait
    margins:     gui.PrintMargins{top: 36, right: 36, bottom: 36, left: 36}
    source:      gui.PrintJobSource{kind: .current_view}
    paginate:    true
    scale_mode:  .actual_size
    header:      gui.PrintHeaderFooterCfg{enabled: true, left: "{title}", right: "{page}/{pages}"}
})

if !result.is_ok() {
    eprintln('${result.error_code}: ${result.error_message}')
}
```

## Native print dialog

`run_print_job` opens native print flow and returns `PrintRunResult`.

```v ignore
result := w.run_print_job(gui.PrintJob{
    title:       "Print"
    job_name:    "Monthly Report"
    paper:       .a4
    orientation: .portrait
    source:      gui.PrintJobSource{kind: .current_view}
    copies:      2
    page_ranges: [gui.PrintPageRange{from: 1, to: 3}]
    duplex:      .long_edge
    color_mode:  .grayscale
})

match result.status {
    .ok { println('printed: ${result.pdf_path}') }
    .cancel { println('canceled') }
    .error { eprintln('${result.error_code}: ${result.error_message}') }
}
for warn in result.warnings {
    eprintln('warning: ${warn.message}')
}
```

Print existing PDF path:

```v ignore
result := w.run_print_job(gui.PrintJob{
    title:  "Print Existing PDF"
    source: gui.PrintJobSource{kind: .pdf_path, pdf_path: "/tmp/report.pdf"}
})
```

## Result model

`PrintRunResult` fields:

| Field | Meaning |
|---|---|
| `status` | `.ok`, `.cancel`, `.error` |
| `error_code` | machine code (`unsupported`, `invalid_cfg`, `io_error`, `render_error`) |
| `error_message` | human-readable detail |
| `pdf_path` | generated/printed PDF path when status is `.ok` |
| `warnings` | best-effort backend warnings for ignored/unsupported options |
