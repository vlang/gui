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

## Raster export

When sokol/GPU is initialized (normal app runtime),
`export_print_job` uses the raster pipeline: each page is
rendered to an offscreen GPU target, read back as pixels,
JPEG-encoded, and embedded as a PDF image XObject. This
preserves full visual fidelity (gradients, rounded rects,
SVG content). Header/footer text remains vector overlay.

Falls back to the vector PDF path in test environments
where sokol is not initialized.

### Raster settings

| Field | Default | Range | Effect |
|---|---|---|---|
| `raster_dpi` | 300 | 72-1200 | Pixels per inch |
| `jpeg_quality` | 85 | 10-100 | JPEG compression |

### Scale modes

- `.actual_size` with `paginate: true` — content at 1:1,
  split across pages.
- `.fit_to_page` with `paginate: false` — entire source
  scaled to fit one page.

### Source dimensions

`source_width` and `source_height` define the capture area.
If omitted (zero), they default to the window size. When
`source_height` exceeds the actual window height (OS may
constrain), the raster path generates a temporary print
layout with the full height so scroll containers do not
clip content.

```v ignore
result := w.export_print_job(gui.PrintJob{
    output_path:   '/tmp/report.pdf'
    paper:         .a4
    scale_mode:    .fit_to_page
    source_width:  520
    source_height: 1600
    raster_dpi:    300
    jpeg_quality:  90
    header: gui.PrintHeaderFooterCfg{
        enabled: true
        left:    '{title}'
        right:   '{page}/{pages}'
    }
})
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
