# Codebase Concerns

**Audit Date:** 2026-02-05

## Tech Debt

**Markdown Parser Complexity & Maintenance:**
- Issue: `xtra_markdown.v` is a monolithic 1800-line parser implementing complex state machines
  for blockquotes, lists, and tables.
- Impact: High risk of regressions when adding new markdown features. Difficult to optimize
  beyond the current source-level caching.
- Fix approach: Refactor into a modular parser (Block vs. Inline parsers).

**Future Dialog Types Stubbed:**
- Issue: `browse`, `save`, and `color` dialog types remain stubs in `view_dialog.v`.
- Impact: Core desktop application features (file picking) are unavailable.
- Fix approach: Implement native OS dialog wrappers or a dedicated V-gui file browser.

**Shader Limitation (Alpha & Stop Count):**
- Issue: Current gradient shaders in `shaders_glsl.v` and `shaders_metal.v` hardcode alpha=1.0
  and are limited to 3 color stops.
- Files: `shaders_glsl.v:279`, `shaders_metal.v:321`.
- Impact: Multi-stop gradients (>3) and semi-transparent gradients are not yet supported.
- Fix approach: Update uniform buffers to pass alpha data and expand the stop count limit.

## Known Bugs & Issues

**Silent Resource Load Failures:**
- Issue: Failures to load SVG, images, or fonts are logged to stderr but not reflected in the UI.
- Files: `render.v:190` (Text), `render.v:723` (Image), `render.v:984` (SVG).
- Risk: Users see an incomplete UI without knowing why resources are missing.
- Fix approach: Render "error placeholders" (e.g., magenta squares or warning icons).

**Window Initialization Panic:**
- Issue: `window.v` panics if the text rendering system (`vglyph`) fails to start.
- Files: `window.v:130`.
- Risk: Immediate crash on systems with driver/OpenGL incompatibilities.

## Threading & Synchronization Concerns

**Unsafe Lock Usage Pattern:**
- Issue: `xtra_window.v` warns that locking twice in the same thread causes deadlocks.
- Risk: Complex event -> animation -> mutation chains can inadvertently cause a deadlock.
- Current mitigation: Deferred callbacks executed outside the lock.
- Recommendation: Transition to an atomic command queue for UI state updates.

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

## Addressed Concerns (2026-02-05)

- **Panics on Configuration Errors:** Replaced panics in RangeSlider, Menubar, Menu, and MenuItem
  with log.warn and safe fallback values to prevent application crashes during development.
- **Indefinite Progress Bar:** Fully implemented using KeyframeAnimation.
- **Markdown Parsing Caching:** Implemented via source-hash lookup in Window state.
- **Undo/Redo Memory Growth:** BoundedStack now enforces a 50-item limit.
- **Gradient Rendering Hack:** Vertex interpolation replaced by fragment shader pipeline.
- **Layout Parent Stability:** `Layout` moved to `@[heap]` and `layout_arrange` reordered.
- **Text Width Performance:** Measurement results are cached by the underlying text system.
