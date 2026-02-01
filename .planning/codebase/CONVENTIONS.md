# Coding Conventions

**Analysis Date:** 2026-02-01

## Naming Patterns

**Files:**
- Module files: snake_case (e.g., `view_button.v`, `xtra_math.v`)
- Test files: Prefix with underscore + snake_case (e.g., `_event_test.v`,
  `_layout_test.v`, `_bounded_map_test.v`)
- C integration files: Add `.c` suffix (e.g., `titlebar.c.v`)

**Functions:**
- Public functions: snake_case (e.g., `button()`, `f32_clamp()`,
  `layout_arrange()`)
- Private/internal functions: snake_case (e.g., `layout_parents()`,
  `layout_widths()`)
- Test functions: Prefix with `test_` (e.g., `test_modifier_has()`,
  `test_layout_parents()`)
- Helper functions in tests: Prefix with create/make prefix
  (e.g., `make_test_layout()`, `create_mock_shape()`)

**Variables:**
- snake_case for all variables (e.g., `color_hover`, `min_width`,
  `text_style`)
- Constants: snake_case with `const` keyword (e.g., `f32_tolerance`,
  `test_red`, `empty_layout`)
- Mutable variables in loops: Use `mut` keyword explicitly
  (e.g., `mut layout Layout`, `mut window Window`)

**Types:**
- Struct/Interface names: PascalCase (e.g., `Layout`, `Shape`, `ButtonCfg`,
  `Modifier`, `Color`)
- Enum variants: Lowercase with dots (e.g., `.left_to_right`, `.top_to_bottom`,
  `.fill`, `.none`, `.shift`)
- Type configuration structs: End with `Cfg` (e.g., `ButtonCfg`, `ThemeCfg`,
  `MarkdownStyle`)

## Code Style

**Formatting:**
- V's built-in formatter: `v fmt -w <file>`
- No external formatting tool config detected (not using prettier or eslint)
- Consistent indentation: tabs/spaces as per V standard

**Linting:**
- V has built-in linting via `v -check-syntax`
- No explicit `.eslintrc` or linter config file in repository

**Attributes:**
- Use V attributes for performance/memory hints
- Example: `@[heap; minify]` on config structs (e.g., `ButtonCfg`)
- `@[inline]` on small utility functions (e.g., `f32_clamp()`, `f32_are_close()`)

## Import Organization

**Order (observed pattern in codebase):**
1. V standard library imports (e.g., `import gg`, `import vglyph`)
2. Local module imports (implicit - all files in `gui` module)

**Path Aliases:**
- Not heavily used; full module paths referenced (e.g., `gui.button()`,
  `gui.Layout`)

## Error Handling

**Patterns:**
- Optional return values with `?` suffix for functions that may fail
  (e.g., `adjust_font_size() ?Theme`)
- Error propagation via `or { ... }` blocks for handling missing values
  - Example: `m.get('a') or { -1 }` to provide default on none
  - Example: `text_run := rt.runs.filter(...)[0] or { panic('no Hello run') }`
- No explicit error types; uses option types for failure handling
- Assertion failures trigger panics (test context appropriate)

## Logging

**Framework:** No dedicated logging framework detected

**Patterns:**
- Uses `println()` for debug output (commented out in production code)
- Example in `layout.v`: `// println(stopwatch.elapsed())`
- No structured logging; raw console output for diagnostics

## Comments

**When to Comment:**
- Function documentation: Provide context before public functions
- Complex algorithms: Document multi-step processes with explanatory comments
  - Example: `layout.v` documents the Clay UI algorithm with references
- Section headers: Use comment blocks with dashes for logical grouping
  - Example: `// ---- Layout Pipeline ----`
- Implementation notes: Document non-obvious behavior or constraints
  - Example: Notes on @[heap] causing flickering in `layout_types.v`

**JSDoc/TSDoc:**
- V uses comment-based documentation format
- Functions document parameters and return values in comment above definition
- Example from `view_button.v`:
  ```v
  // ButtonCfg configures a clickable [button](#button). It won't respond to
  // mouse interactions if an on_click handler is not provided.
  ```
- Reference links to other types: `[ButtonCfg](#ButtonCfg)`

## Function Design

**Size:** Keep functions focused and reasonably small

**Parameters:**
- Configuration structs for many parameters (e.g., `ButtonCfg`, `ThemeCfg`)
- Use spread syntax in calls to pass many config values
  ```v
  gui.button(
    min_width: 90
    max_width: 90
    content: [gui.text(text: 'Click')]
    on_click: fn (...) { ... }
  )
  ```
- Callback functions passed as function pointers
  (e.g., `on_click fn (&Layout, mut Event, mut Window) bool`)

**Return Values:**
- Single return for simple operations
- Multiple returns for tuple results (e.g., `(u32, u32)` from `u32_sort()`)
- Option types `?Type` for fallible operations
- Bare types for layout functions (e.g., `Layout`, `[]Layout`)

## Module Design

**Exports:**
- All public entities use `pub` keyword explicitly
- Public structs: `pub struct Layout { ... }`
- Public functions: `pub fn button(cfg ButtonCfg) View { ... }`
- Public constants: `pub const black = Color{ ... }`

**Barrel Files:**
- No barrel files pattern detected
- All files co-exist in `gui` module
- Views organized by component (e.g., `view_button.v`, `view_dialog.v`)
- Utilities organized by domain (e.g., `xtra_math.v`, `xtra_text.v`)

---

*Convention analysis: 2026-02-01*
