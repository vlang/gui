# Architecture

**Analysis Date:** 2026-02-01

## Pattern Overview

**Overall:** Reactive component-based architecture with layered separation between stateless
views, layout calculation, rendering, and event handling.

**Key Characteristics:**
- Views are pure functions (`fn(window &Window) View`) that generate UI descriptions
- Layout engine transforms views into positioned shapes via a multi-pass constraint solver
- Event system traverses layout tree to dispatch input to correct handlers
- Window manages global state, animations, and orchestrates the full pipeline
- Theme system provides consistent styling across all components

## Layers

**Application Layer:**
- Purpose: Entry point for programs using v-gui
- Location: `examples/` directory
- Contains: Demonstration applications (buttons, markdown, table_demo, etc.)
- Depends on: Window, view constructors, event handlers
- Used by: End-user applications

**Window Management Layer:**
- Purpose: Central orchestrator managing app lifecycle, state, events, and rendering
- Location: `window.v`, `xtra_window.v`
- Contains: Window struct, initialization, frame loop, event dispatch
- Depends on: gg (graphics), View generators, Layout engine
- Used by: Application code, animation system

**View Layer:**
- Purpose: Stateless UI descriptions generated each frame
- Location: `view.v`, `view_*.v` (31 view types), `view_state.v`
- Contains: View interface, configuration structs (ViewCfg), state management
- Depends on: Window, event handlers
- Used by: Application code (via factory functions like `column()`, `button()`, `text()`)

**Layout Engine:**
- Purpose: Transforms views into positioned, sized elements
- Location: `layout.v`, `layout_*.v` (layout_sizing.v, layout_position.v, layout_types.v,
layout_query.v, layout_stats.v)
- Contains: Multi-pass constraint solver with 12 distinct phases
- Depends on: View/Shape data structures, animation system
- Used by: Window frame loop via `layout_arrange()`

**Shape System:**
- Purpose: Unified data structure holding layout, styling, and event handler information
- Location: `shape.v`
- Contains: Shape struct with 80+ fields organized by size/alignment class
- Depends on: Styling system (Gradient, BoxShadow), TextSystem (vglyph)
- Used by: Layout engine, rendering system, event handlers

**Styling System:**
- Purpose: Visual properties for shapes and components
- Location: `styles.v`, `theme.v`, `theme_types.v`, `theme_defaults.v`, `color.v`
- Contains: BoxShadow, Gradient, TextStyle, component-specific styles
- Depends on: None (applies to Shape and Renderer systems)
- Used by: View configuration, Shape system, Rendering

**Rendering System:**
- Purpose: Converts shapes to drawable primitives
- Location: `render.v`, `shaders.v`, `shaders_glsl.v`, `shaders_metal.v`
- Contains: Renderer types (DrawCircle, DrawText, DrawImage, DrawShadow), shader pipeline
- Depends on: gg (graphics context), sokol.sgl (low-level graphics)
- Used by: Window frame loop via `render_layout()`

**Event System:**
- Purpose: Captures user input and dispatches to correct handlers
- Location: `event.v`, `event_handlers.v`, `event_traversal.v`
- Contains: Event struct, traversal order logic, callback execution
- Depends on: Layout tree (Shape callbacks)
- Used by: Window frame loop, triggered by gg events

**Animation System:**
- Purpose: Smooth transitions and time-based updates
- Location: `animation.v`, `animation_*.v` (easing, keyframe, layout, spring, tween, hero)
- Contains: Animation interface, Animate, KeyframeAnimation, LayoutTransition, TweenAnimation
- Depends on: Window, time module
- Used by: Layout engine (hero animations, layout transitions), application code

**Utility & Extra Modules:**
- Purpose: Helper functionality for text, math, markdown, SVG, etc.
- Location: `xtra_*.v` (9 files), `vector.v`, `bounded_*.v`, `fonts.v`
- Contains: Text layout (vglyph integration), markdown rendering, SVG parsing, RTF support
- Depends on: Third-party libraries (vglyph, markdown parsers)
- Used by: View components, rendering system

## Data Flow

**View Generation → Layout → Render:**

1. Application calls `window.update_view(fn)` with a view generator function
2. Window calls view generator to produce root View
3. `generate_layout()` recursively converts View tree to Layout tree
4. `layout_arrange()` executes 12-phase layout pipeline:
   - Phase 1-2: Calculate intrinsic widths (horizontal constraints)
   - Phase 3-4: Calculate intrinsic heights (vertical constraints)
   - Phase 5-6: Distribute fill space
   - Phase 7: Position elements (absolute X, Y)
   - Phase 8-12: Handle disabled states, scrolling, amendments, animations, clipping
5. `render_layout()` converts Layout/Shape tree to flat Renderer array
6. gg renders Renderer array to screen

**Event Processing:**

1. User input captured by sokol.sapp
2. Converted to gui.Event in `event_fn()`
3. Event dispatched via `event_handlers.py()` traversing Layout tree
4. Correct handler invoked based on focus/hover state
5. Handler updates Window state or application state
6. `window.refresh_window` flag triggers next view generation

**State Management:**

- **Application State**: Passed to window, accessible in view generator via `window.state`
- **View State**: ViewState struct manages focus, selection ranges, scroll positions (transient)
- **Layout Cache**: Layout tree cached in Window, recomputed only when `refresh_window=true`

## Key Abstractions

**View Interface:**
- Purpose: Stateless description of UI structure
- Examples: `column()`, `row()`, `button()`, `text()`, `input()`
- Pattern: Factory functions return View implementations, each with `generate_layout()` method

**Shape Struct:**
- Purpose: Unified representation of a positioned, styled UI element
- Pattern: Single struct with 80+ fields (organized by memory alignment), used throughout system

**Layout Tree:**
- Purpose: Hierarchical tree of positioned shapes
- Pattern: Parent-child relationship via `layout.parent`, children accessed via `layout.children[]`

**Renderer Types:**
- Purpose: Low-level drawing instructions (DrawCircle, DrawText, DrawImage, etc.)
- Pattern: Union-like types converted from Shape data, consumed by gg

**Animation Interface:**
- Purpose: Time-based modifications to shapes or properties
- Pattern: Implementations include Animate, KeyframeAnimation, LayoutTransition, TweenAnimation

## Entry Points

**main():**
- Location: Examples in `examples/*.v`
- Triggers: Application startup
- Responsibilities: Create Window via `gui.window()`, set initial view via `on_init` callback

**Frame Loop:**
- Location: `frame_fn()` in `window.v`
- Triggers: Every display refresh (sokol.sapp driven)
- Responsibilities: Generate layout, render, update animations, dispatch events

**Event Handler:**
- Location: `event_fn()` in `window.v`, dispatched via `event_handlers.v`
- Triggers: User input (mouse, keyboard, window events)
- Responsibilities: Traverse layout tree, execute shape callbacks, update focus/hover state

## Error Handling

**Strategy:** Minimal runtime errors; most issues caught at compile time or in examples.

**Patterns:**
- Optional pointers (`unsafe { nil }`) for nullable fields in Shape and other structs
- Result types in window initialization (e.g., text system initialization may fail)
- Logging via `log` module for debug output and warnings
- Assertions in layout calculations for invariant violations

## Cross-Cutting Concerns

**Logging:** Via V's `log` module, configured in Window initialization. Set via `log.set_level()`.

**Validation:** Layout engine includes assertions for invariants (e.g., child count consistency).

**Authentication:** Not applicable; this is a UI framework.

**Theme Application:** Global variable `gui_theme` applied to all components via default values in
Cfg structs. Overrideable per-component via explicit color/style parameters.

**Focus Management:** ViewState tracks focused element ID; keyboard events dispatch to focused
shape's `on_char`/`on_keydown` handlers.

**Scroll Management:** Scroll position tracked in ViewState; scroll containers clip children and
adjust positions via `layout_adjust_scroll_offsets()`.

---

*Architecture analysis: 2026-02-01*
