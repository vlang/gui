# Codebase Concerns

**Analysis Date:** 2026-02-01

## Tech Debt

**Gradient Rendering Incomplete:**
- Issue: Linear gradient implementation uses a HACK (line 838 in `render.v`) that only interpolates
  start/end colors for the 4 corners. Comprehensive multi-stop gradient support requires fragment
  shader or texture-based approach.
- Files: `render.v:810-853`, `render.v:855-887`, `render.v:889-969`
- Impact: Multi-stop gradients display incorrectly. Border gradients also incomplete. Visual artifacts
  on gradient-based designs.
- Fix approach: Implement gradient texture generation or custom fragment shader supporting arbitrary
  gradient stops.

**Markdown Parser Complexity & Incomplete State:**
- Issue: `xtra_markdown.v` (1814 lines) implements full markdown parser with bounds-checking on
  multi-line constructs (max_blockquote_lines=100, max_table_lines=500, etc.) to prevent runaway
  parsing. Parser has significant complexity but may not handle all edge cases correctly.
- Files: `xtra_markdown.v:1-200+` (core parsing), `_markdown_test.v:717 lines` (tests)
- Impact: Large/complex markdown may fail to parse. Nested/ambiguous markdown syntax risks crashes
  or unexpected rendering. Code blocks, tables, lists may misbehave.
- Fix approach: Refactor into smaller parsing functions. Add comprehensive test suite covering edge
  cases. Consider using proven markdown parsing library if available in V.

**Progress Bar Missing Feature:**
- Issue: `indefinite` mode marked as not implemented (line 28 in `view_progress_bar.v`).
- Files: `view_progress_bar.v:28`
- Impact: Loading spinners/indeterminate progress bars cannot be created.
- Fix approach: Implement indefinite animation loop with rotation or pulsing effect.

**Future Dialog Types Stubbed:**
- Issue: File browser dialog, save dialog, and color picker dialog marked as future TODO (lines 10-13
  in `view_dialog.v`).
- Files: `view_dialog.v:10-13`
- Impact: These common dialogs not available. Users must implement custom file browsers.
- Fix approach: Implement native file dialogs. Color picker requires color selection UI.

**Column Selection Not Implemented:**
- Issue: Column can function as list box but selection logic not implemented (line 48 in
  `examples/column_scroll.v`).
- Files: `examples/column_scroll.v:48`
- Impact: No built-in multi-item selection for columns. Must implement manually in application code.
- Fix approach: Add selection state tracking and highlight rendering for column children.

## Known Bugs & Issues

**Text Rendering Error Handling:**
- Issue: Text render failures are logged but app continues with invisible text (lines 190-195 in
  `render.v`). No visual indicator that text failed to render.
- Files: `render.v:190-195`
- Trigger: Font files missing, text rendering system failure, character encoding issues.
- Workaround: Check logs for render errors. Ensure font files are present and readable.
- Risk: Silent failures make debugging difficult. Users won't know why text isn't appearing.

**SVG Loading Error Handling:**
- Issue: SVG load failures logged and return silently (lines 984-987 in `render.v`). SVG simply won't
  appear if load fails.
- Files: `render.v:984-987`
- Trigger: SVG file not found, parse error, memory allocation failure.
- Workaround: Check logs. Ensure SVG files exist and are valid.
- Risk: No fallback rendering or error indicator.

**Image Loading Error Handling:**
- Issue: Image load failures logged silently (lines 723-726 in `render.v`).
- Files: `render.v:723-726`
- Workaround: Check logs. Ensure image files exist.
- Risk: Silent failures.

**Window Initialization Panic on Text System Failure:**
- Issue: Window panics if text system (vglyph) fails to initialize (line 128 in `window.v`).
- Files: `window.v:128`
- Trigger: OpenGL incompatibility, vglyph library error, graphics driver issues.
- Workaround: Update graphics drivers. Check platform OpenGL support.
- Risk: Application crash on startup. No graceful degradation.

## Threading & Synchronization Concerns

**Unsafe Lock Usage Pattern:**
- Issue: `xtra_window.v:149` explicitly warns "Locking twice in the same thread results in a dead
  lock or panic". Double-lock in animation callbacks avoided via deferred callback pattern
  (`animation.v:99-100`), but this is fragile.
- Files: `xtra_window.v:145-150`, `animation.v:97-101`
- Risk: If callback handling changes, deadlock possible. Manual coordination required.
- Current mitigation: Deferred callbacks executed outside lock.
- Recommendation: Document lock safety clearly. Consider refactoring to avoid manual locking if
  possible.

**Mermaid Diagram Async Fetch:**
- Issue: `fetch_mermaid_async` spawns background thread without timeout control (line 51 in
  `xtra_mermaid.v`). Comment notes "V's http.fetch doesn't support timeout config".
- Files: `xtra_mermaid.v:47-52`
- Risk: Hung HTTP request can block indefinitely. No way to cancel in-flight requests. External
  kroki.io API dependency.
- Current mitigation: Mermaid source sent to external API for rendering (PNG format).
- Recommendation: Implement timeout wrapper. Add cancellation mechanism. Consider caching to reduce
  API calls.

**Animation Loop Threading:**
- Issue: Animation loop spawned as background thread (line 138 in `window.v`). Accesses window state
  with mutex protection (`animation.v` uses lock/unlock), but window mutation in animation callbacks
  requires careful coordination.
- Files: `window.v:138`, `animation.v:80-101`
- Risk: Complex state machine. Potential race conditions if callback tries to update state without
  proper locking.
- Current mitigation: Deferred callbacks pattern.
- Recommendation: Document threading model clearly. Add tests for concurrent animation scenarios.

## Unsafe Pointer Usage

**Heavy Unsafe Pointer Usage Throughout:**
- Issue: Framework uses `unsafe { nil }` extensively for optional pointers (90+ occurrences in grep).
  Default values for function pointers (event handlers, callbacks) use unsafe nil.
- Files: `view_button.v:24-25`, `shape.v:20-35`, `view_container.v:172-180`, and 80+ other files
- Risk: Misuse of unsafe pointers can cause segfaults. No null safety checking at call sites.
- Current pattern: Callbacks checked with `if callback != unsafe { nil }` before calling.
- Recommendation: Document unsafe pointer patterns. Add safety guidelines. Consider using Option types
  where possible.

**Layout Parent Pointer Manipulation:**
- Issue: Layout.parent is unsafe pointer set with `unsafe { parent }` (line 96 in `layout.v`).
  Tests manually verify parent relationships with unsafe casts (`_layout_test.v:22-26`).
- Files: `layout.v:96`, `_layout_test.v:22-26`, `_integration_test.v:215-224`
- Risk: Dangling parent pointers if layout tree modified during traversal.
- Mitigation: Bounds checking and parent verification in layout traversal.
- Recommendation: Validate parent pointer safety during layout mutations.

**Shape Pointer Fields:**
- Issue: Shape has multiple unsafe pointer fields for optional objects (vglyph_layout, rich_text,
  shadow, gradient, border_gradient) - lines 20-24 in `shape.v`.
- Files: `shape.v:20-24`
- Risk: Null dereferences if optional fields accessed without checks.
- Mitigation: Check-before-use pattern in render functions.
- Recommendation: Document which pointers are optional and when they're initialized.

## Memory Management Concerns

**Large Array Allocations in Parser:**
- Issue: Markdown parser creates many intermediate arrays during parsing. Example at line 655 in
  `xtra_markdown.v`: `mut all_runs := []RichTextRun{}` with no cap hint, causing re-allocations.
- Files: `xtra_markdown.v:655`, `xtra_markdown.v:613-621`, `xtra_markdown.v:666-679`
- Impact: Performance degradation on large markdown documents. Memory fragmentation.
- Fix approach: Pre-allocate arrays with appropriate capacity hints. Profile memory usage on large
  documents.

**Undo/Redo Stack Unbounded in InputState:**
- Issue: `BoundedStack[InputMemento]` used for undo/redo but bounds not visible in struct definition
  (line 25 in `view_input.v`). Memory growth unchecked if user makes many edits.
- Files: `view_input.v:25-26`, `bounded_stack.v` (need to verify max size)
- Impact: Unbounded memory growth in long editing sessions.
- Fix approach: Verify BoundedStack has enforced max capacity. Document limits.

**SVG Triangle Array No Bounds Check:**
- Issue: DrawSvg stores `triangles []f32` with no length validation (line 100 in `render.v`). Large
  SVGs could allocate huge arrays.
- Files: `render.v:100`, `draw_triangles:1005-1033`
- Impact: Memory exhaustion on pathological SVG files.
- Fix approach: Add max size validation when loading SVGs. Validate triangle array lengths.

## Performance Bottlenecks

**Gradient Computation Per Frame:**
- Issue: Gradient colors interpolated per-vertex in `draw_quad_gradient` (lines 855-887 in
  `render.v`) every frame with no caching.
- Files: `render.v:855-887`
- Impact: Repeated color calculations on every render. Slow on many gradient shapes.
- Improvement: Cache gradient color computations. Use GPU texture for gradients instead.

**Markdown Parsing on Every View Update:**
- Issue: `markdown_to_blocks` called every time markdown view regenerates (in `view_markdown.v`).
  No caching of parsed markdown.
- Files: `xtra_markdown.v:125-600+`, `view_markdown.v`
- Impact: Large markdown documents re-parsed on every UI update. CPU-bound operation.
- Improvement: Cache parsed blocks keyed by markdown source hash. Invalidate on source change.

**Layout Tree Traversal Repeated:**
- Issue: Layout traversal functions called multiple times per frame (position, render, event
  handling). No intermediate caching of layout queries.
- Files: `layout_query.v`, `layout_position.v`, `render.v`
- Impact: O(n) traversals for every operation. Scales poorly with deep layout trees.
- Improvement: Cache layout query results within frame. Invalidate when layout changes.

**Text Width Computation:**
- Issue: `text_width` called repeatedly during text selection rendering and layout calculations (line
  613 in `render.v`). No caching of text metrics.
- Files: `render.v:613`, `render.v:616`
- Impact: Repeated measurements slow down text selection rendering.
- Improvement: Cache text widths per font/text combination.

## Fragile Areas

**Text Selection Logic Complex:**
- Issue: Text selection rendering involves byte-to-rune conversion, line intersection, layout
  queries, and special password field handling (lines 592-660 in `render.v`).
- Files: `render.v:592-660`, `render.v:513-519`
- Why fragile: Many moving parts. UTF-8 byte indexing error-prone. Password field special case adds
  complexity.
- Safe modification: Add comprehensive tests for text selection. Test with various UTF-8 characters,
  multiline text, and password fields.
- Test coverage: `_render_test.v` has basic renderer tests but limited text selection coverage.

**Cursor Position Calculation:**
- Issue: Cursor position depends on vglyph layout accuracy, byte-to-rune conversion, and fallback
  logic (lines 663-710 in `render.v`).
- Files: `render.v:663-710`
- Why fragile: Fallback to end-of-line cursor can place cursor visually off-screen.
- Safe modification: Add edge case tests for cursor at EOF, empty text, various font sizes.

**Layout Clip Recursion:**
- Issue: Recursive layout rendering with clip rectangle updates (lines 247-287 in `render.v`).
- Files: `render.v:247-287`
- Why fragile: Deep recursion possible. Clip rect calculation involves padding logic that could be
  off-by-one.
- Safe modification: Limit recursion depth. Add clipping sanity checks.

**Event Delegation Chain:**
- Issue: Events traverse layout tree with multiple handler callbacks (`event.v`, `event_handlers.v`,
  `event_traversal.v`). Complex dispatch logic with multiple callback types.
- Files: `event.v:1-400+`, `event_handlers.v:1-400+`, `event_traversal.v:1-100+`
- Why fragile: Many callback types (on_click, on_keydown, on_mouse_move, etc.). Ordering matters.
- Safe modification: Document event propagation order. Add event ordering tests.
- Test coverage: `_event_test.v` covers basic events but not complex delegation.

## Security Considerations

**External API Dependency - Kroki.io:**
- Risk: Mermaid diagrams sent to external kroki.io API for rendering (line 50 in `xtra_mermaid.v`).
- Files: `xtra_mermaid.v:47-52`
- Current mitigation: Comment documents external dependency.
- Recommendations:
  1. Warn users about external API calls
  2. Consider offline rendering alternative
  3. Add option to disable Kroki integration
  4. Validate Kroki response before using

**Menu ID Validation:**
- Risk: Menu IDs checked for duplicates with panic on failure (lines 85-87 in `view_menubar.v`).
  Could be triggered by malformed user input.
- Files: `view_menubar.v:85-87`, `view_menu.v:191`
- Current mitigation: Panic stops execution.
- Recommendation: Return error result instead of panic. Let user handle gracefully.

**Panic On Invalid Configuration:**
- Risk: Multiple panics on invalid input:
  - Range slider: min >= max (line 59-61 in `view_range_slider.v`)
  - Menu item: separator with action (line 33-35 in `view_menu_item.v`)
  - Menu ID: blank IDs (line 95 in `view_menu_item.v`)
  - Menubar: zero id_focus (lines 79-81 in `view_menubar.v`)
- Files: `view_range_slider.v:59-61`, `view_menu_item.v:33-35`, `view_menu_item.v:95`,
  `view_menubar.v:79-81`, `view_menu.v:10-12`
- Risk: User input directly crashes app instead of returning validation error.
- Recommendation: Convert panics to result types. Return validation errors instead.

## Test Coverage Gaps

**Markdown Edge Cases:**
- What's not tested: Complex nesting (blockquotes in lists), malformed tables, huge documents,
  unusual UTF-8 sequences, mixed fence types.
- Files: `_markdown_test.v:717 lines` (existing tests), `xtra_markdown.v:1814 lines` (untested paths)
- Risk: Parser may fail silently or crash on unusual input. Bounds checking (max_table_lines=500)
  untested.
- Priority: High - markdown is central feature affecting document rendering.

**Text Rendering UTF-8 Safety:**
- What's not tested: Emoji sequences, RTL text, combining characters, zero-width joiners.
- Files: `render.v:495-580`, `_render_test.v:79 lines`
- Risk: Text selection/cursor placement incorrect with complex Unicode. Password char repeat may
  miscalculate visible length.
- Priority: High - affects all text input/display.

**Layout Recursion Limits:**
- What's not tested: Deeply nested layouts (>100 levels), circular parent references, massive
  child counts.
- Files: `render.v:247-287`, `layout.v`, `_layout_test.v:354 lines`
- Risk: Stack overflow or performance collapse on pathological layouts. Parent cycle could hang.
- Priority: Medium - unlikely but catastrophic if occurs.

**Thread Safety:**
- What's not tested: Concurrent access to window state during animations, double-lock scenarios,
  race conditions between animation loop and event handlers.
- Files: `animation.v`, `xtra_window.v:145-150`
- Risk: Deadlock, data corruption, or crashes under concurrent load.
- Priority: High - threading bugs hard to reproduce and debug.

**Shader Pipeline Initialization:**
- What's not tested: Shader init failure handling, multiple window instances, pipeline state
  corruption.
- Files: `shaders.v:706 lines`, `render.v:789-807` (blur pipeline), `render.v:831-852` (gradient
  pipeline)
- Risk: Shader compilation failure could silently disable effects.
- Priority: Medium - rare but affects visual output.

## Missing Critical Features

**No Undo/Redo UI:**
- Problem: Undo/redo implemented in InputState but no way to trigger undo/redo from UI. Keyboard
  shortcuts (ctrl+z) work but UI buttons unavailable.
- Impact: Users can't undo/redo operations. Complex data entry loses work on mistakes.

**No Accessibility Support:**
- Problem: No screen reader support, no high contrast mode, no keyboard-only navigation.
- Impact: App unusable for users with disabilities.

**No Right-to-Left (RTL) Text Support:**
- Problem: Text rendering assumes LTR. RTL text displays backwards.
- Impact: Arabic, Hebrew, Persian users see corrupted UI.

**No IME Support:**
- Problem: Input method editors (for CJK input) not supported.
- Impact: Chinese/Japanese/Korean users cannot type.

## Dependencies at Risk

**Vglyph Dependency:**
- Risk: Text system crashes app if vglyph initialization fails (line 128 in `window.v`). Single
  point of failure for entire rendering pipeline.
- Impact: No text rendering = app unusable. Panic on startup.
- Current mitigation: Warning logs before panic.
- Recommendation: Implement fallback text renderer. Handle vglyph failure gracefully.

**Sokol/GG Dependency:**
- Risk: Graphics context creation can fail on incompatible systems. Window.ui initialized in
  gg.new_context but errors not fully handled.
- Impact: App fails on older hardware or unsupported platforms.
- Recommendation: Document platform requirements. Test on minimum spec systems.

## Scaling Limits

**Layout Tree Depth:**
- Current capacity: Recursive render supports arbitrary depth (limited by stack).
- Limit: Deep nesting (>1000 levels) causes stack overflow or O(n²) behavior.
- Scaling path: Implement iterative layout instead of recursive. Add depth limit checks.

**Array Allocations in Markdown:**
- Current capacity: No pre-allocated arrays for most markdown blocks.
- Limit: Large markdown (>10MB) causes memory exhaustion.
- Scaling path: Stream parsing for huge documents. Implement pagination.

**SVG Complexity:**
- Current capacity: SVG triangulated and stored as f32 array.
- Limit: Very complex SVGs (>100k triangles) slow down rendering.
- Scaling path: Implement LOD (level-of-detail) for large SVGs. Cache triangulation.

**Shader Pipeline Count:**
- Current capacity: 3 pipelines (rounded_rect, shadow, blur).
- Limit: Many simultaneous effects could degrade performance.
- Scaling path: Consolidate into single mega-shader or use compute shaders.

---

*Concerns audit: 2026-02-01*
