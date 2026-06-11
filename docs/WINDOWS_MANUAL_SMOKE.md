# Windows Manual Smoke Matrix

Use this matrix after the non-interactive Windows tests and focused example
compiles pass. These checks are intentionally manual because they exercise real
OS UI, handlers and GPU behavior.

Record every run with:

- Windows version
- V version
- compiler and architecture
- `vcpkg list`
- command used to build each smoke executable
- pass/fail result, notes and screenshots where useful

## Preconditions

- Native Windows machine or GitHub Windows runner with interactive/manual
  access.
- MSVC/vcpkg path from [`WINDOWS.md`](WINDOWS.md).
- `v run _windows_preflight.vsh` passes on native Windows.
- `dialogs_smoke.exe`, `printing_smoke.exe` and `notification_smoke.exe`
  compiled with `-cc msvc -W`.
- WSL and Wine results are marked as prefilters only, never as final passes.

## Matrix

### Setup

- Check: run the non-interactive tests from `WINDOWS.md`.
- Expected: all targeted tests pass without opening modal UI.
- Evidence: command output.

### Dialogs

- Open one file with named filters. Expect a native picker, a returned path and
  meaningful filter labels. Evidence: screenshot plus callback log.
- Select multiple files. Expect every selected path in the callback log.
- Save with default extension and `confirm_overwrite: true`. Expect native
  overwrite confirmation and the created file path in the callback log.
- Try an existing path with `confirm_overwrite: false`. Expect `.error`
  instead of overwrite.
- Pick a folder. Expect the selected folder path.
- Show info/warning/error messages. Expect native message boxes and `.ok`.
- Accept and reject a confirm dialog. Expect Yes as `.ok` and No as `.cancel`.

### Printing

- Print/export current view through the example. Expect PDF generation before
  native print dispatch.
- Print an existing PDF with the default handler installed. Expect
  `ShellExecute` print dispatch or a structured error.
- Repeat with no default PDF handler if practical. Expect error without crash
  or hang.
- Request copies/ranges/duplex/color. Expect warnings for unsupported or
  unverifiable options; do not claim full option parity.

### Notifications

- Send a notification. Expect a `Shell_NotifyIconW` balloon or a structured
  setup/runtime error.
- Treat this as notification-area fallback evidence only. Do not record it as
  Toast, AppNotification, Action Center, or Windows App SDK parity.

### D3D11 Readback And Export

- Exercise raster export/readback. Expect completion without invalid dimensions,
  overflow, format or startup failure.

### Examples

- Launch dialogs, printing and notification smoke executables. Expect startup
  without missing DLLs and the manual behavior listed above.

### Accessibility

- Inspect with Narrator or Accessibility Insights if available. Current expected
  result is limited: no real UI Automation provider is implemented, so a pass
  can only mean "no crash/no misleading parity claim".
- Do not close Windows accessibility parity until a server-side UIA provider is
  implemented and exposes a useful tree through Windows accessibility tooling.

## Failure Classification

- Missing `vglyph` module imports are setup/preflight failures.
- Missing Pango/Freetype/HarfBuzz/FriBidi/Fontconfig headers, libraries or DLLs
  are setup/preflight failures.
- Modal UI hangs are native Windows behavior blockers.
- Missing PDF handler behavior belongs to printing validation, not dependency
  setup.
- Notification delivery failures are Windows notification backend validation
  items, not dialog/print failures.
- WSL/Wine-only results cannot close a native Windows validation item.
