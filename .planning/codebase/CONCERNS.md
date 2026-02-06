# Codebase Concerns

**Audit Date:** 2026-02-05

## Tech Debt

**Future Dialog Types Stubbed:**
- Issue: `browse`, `save`, and `color` dialog types remain stubs in `view_dialog.v`.
- Impact: Core desktop application features (file picking) are unavailable.
- Fix approach: Implement native OS dialog wrappers or a dedicated V-gui file browser.

## Known Bugs & Issues

**Window Initialization Panic:**
- Issue: `window.v` panics if the text rendering system (`vglyph`) fails to start.
- Files: `window.v:130`.
- Risk: Immediate crash on systems with driver/OpenGL incompatibilities.

## Threading & Synchronization Concerns

**Mermaid Diagram Async Fetch:**
- Issue: `fetch_mermaid_async` lacks timeout or cancellation mechanisms.
- Files: `xtra_mermaid.v:51`.
- Risk: A hung HTTP request can indefinitely hold a thread and a reference to the Window.

## Unsafe Pointer Usage

**Pattern: `unsafe { nil }` for Optional Pointers:**
- Note: Using `unsafe { nil }` for optional pointers and callbacks is an intentional choice
  to keep structure sizes (Layout, Shape) small. Option types have too much overhead here.
- Risk: Requires manual `if ptr != unsafe { nil }` checks at every call site.

**Residual Floating Layout Pointer Risk:**
- Issue: `fix_float_parents` in `float_attach.v` uses unsafe pointer assignment to elements
  within the `floating_layouts` array.
- Risk: While `layout_arrange` now sequences this safely, it remains a fragile area of the
  positioning logic.

## Missing Critical Features

**Internationalization (IME & RTL):**
- Problem: No support for Input Method Editors (for CJK input) or Right-to-Left text.
- Impact: The framework cannot be used for applications in major global markets.

**Accessibility Foundation:**
- Problem: No semantic tree or hooks for screen readers.

## Addressed Concerns (2026-02-06)

- **Atomic Command Queue (Deadlock Prevention):** Implemented `WindowCommand` queue to replace
  direct locking from background threads. All animations and async fetches (Mermaid, Images) now
  queue state updates to the main thread, eliminating deadlock risks from complex event/mutation
  chains.

## Addressed Concerns (2026-02-05)

- **Shader Limitation (Alpha & Stop Count):** Implemented bit-packing for gradient stops,
  enabling full alpha support and expanding the limit from 3 to 6 stops within the existing
  texture matrix uniform space. Updated both GLSL and Metal shaders.
- **Markdown Parser Complexity:** Refactored the monolithic 1800-line `xtra_markdown.v` into five
  focused modules (`types`, `inline`, `blocks`, `tables`, `metadata`), reducing orchestration
  logic to ~500 lines.
- **Silent Resource Load Failures:** Implemented magenta "error placeholders" for failed image and
  SVG loads during the render pass, and updated view fallbacks to use distinct magenta text.
- **Panics on Configuration Errors:** Replaced panics in RangeSlider, Menubar, Menu, and MenuItem
  with log.warn and safe fallback values to prevent application crashes during development.
- **Indefinite Progress Bar:** Fully implemented using KeyframeAnimation.
- **Markdown Parsing Caching:** Implemented via source-hash lookup in Window state.
- **Undo/Redo Memory Growth:** BoundedStack now enforces a 50-item limit.
- **Gradient Rendering Hack:** Vertex interpolation replaced by fragment shader pipeline.
- **Layout Parent Stability:** `Layout` moved to `@[heap]` and `layout_arrange` reordered.
- **Text Width Performance:** Measurement results are cached by the underlying text system.
