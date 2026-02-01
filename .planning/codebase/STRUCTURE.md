# Codebase Structure

**Analysis Date:** 2026-02-01

## Directory Layout

```
/Users/mike/Documents/github/gui/
├── examples/                # Demonstration applications
│   ├── *.v                  # Example programs (60+ apps)
│   └── bin/                 # Compiled example binaries
├── docs/                    # Documentation
│   ├── ARCHITECTURE.md      # High-level architecture overview
│   ├── LAYOUT_ALGORITHM.md  # Layout engine algorithm details
│   ├── ANIMATIONS.md        # Animation system documentation
│   ├── MARKDOWN.md          # Markdown rendering docs
│   ├── TABLES.md            # Table component docs
│   ├── PERFORMANCE.md       # Performance tuning guide
│   ├── SVG.md               # SVG rendering docs
│   ├── GET_STARTED.md       # Quick start guide
│   ├── ROADMAP.md           # Feature roadmap
│   └── *.svg, *.jpeg        # Documentation assets
├── assets/                  # Static assets (icons, fonts, etc.)
├── _planning/codebase/      # GSD analysis documents (generated)
│   ├── ARCHITECTURE.md
│   ├── STRUCTURE.md
│   ├── CONVENTIONS.md       # (for quality focus)
│   ├── TESTING.md           # (for quality focus)
│   ├── STACK.md             # (for tech focus)
│   ├── INTEGRATIONS.md      # (for tech focus)
│   └── CONCERNS.md          # (for concerns focus)
│
└── [Core Module Files] (81 .v files in root)
    │
    ├── _gui.v               # Module definition with global theme
    │
    ├── [Core Infrastructure]
    │   ├── window.v         # Window struct, main event/frame loop
    │   ├── view.v           # View interface definition
    │   ├── event.v          # Event struct, type definitions
    │   ├── layout_types.v   # Layout tree structure
    │   ├── shape.v          # Shape struct (unified drawing model)
    │   ├── render.v         # Renderer types and drawing primitives
    │   ├── animation.v      # Animation interface and registry
    │   ├── styles.v         # BoxShadow, Gradient, TextStyle definitions
    │   └── color.v          # Color struct and utilities
    │
    ├── [Layout Engine]
    │   ├── layout.v         # Main layout pipeline (12 phases)
    │   ├── layout_sizing.v  # Width/height calculation and distribution
    │   ├── layout_position.v # X/Y positioning and alignment
    │   ├── layout_query.v   # Layout tree traversal helpers
    │   └── layout_stats.v   # Debug statistics for layout performance
    │
    ├── [View Components] (31 view types)
    │   ├── view_container.v # Containers: column(), row(), canvas(), circle()
    │   ├── view_text.v      # Text rendering
    │   ├── view_button.v    # Clickable button
    │   ├── view_input.v     # Single/multi-line text input
    │   ├── view_image.v     # Image display
    │   ├── view_rectangle.v # Filled rectangle shape
    │   ├── view_svg.v       # SVG rendering
    │   ├── view_markdown.v  # Markdown rendering
    │   │
    │   ├── [Selection/Input]
    │   ├── view_select.v    # Dropdown selection
    │   ├── view_listbox.v   # Multi-item listbox
    │   ├── view_toggle.v    # Toggle switch
    │   ├── view_radio.v     # Radio button (single)
    │   ├── view_radio_button_group.v # Radio group
    │   ├── view_input_date.v # Date input
    │   ├── view_date_picker.v # Popup date picker
    │   ├── view_date_picker_roller.v # Roller-style date picker
    │   ├── view_range_slider.v # Range slider input
    │   │
    │   ├── [Complex Views]
    │   ├── view_menu.v      # Popup menu
    │   ├── view_menubar.v   # Menu bar (application menus)
    │   ├── view_menu_item.v # Individual menu item
    │   ├── view_table.v     # Table/grid data display
    │   ├── view_tree.v      # Hierarchical tree view
    │   ├── view_listbox.v   # List with scrolling
    │   ├── view_dialog.v    # Modal dialog
    │   ├── view_expand_panel.v # Collapsible panel
    │   ├── view_tooltip.v   # Hover tooltips
    │   │
    │   ├── [Progress/Animation Views]
    │   ├── view_progress_bar.v # Linear progress indicator
    │   ├── view_pulsar.v    # Pulsing animation
    │   ├── view_scrollbar.v # Scroll indicator
    │   │
    │   ├── [Rich Content]
    │   └── view_rtf.v       # Rich Text Format rendering
    │
    ├── [Animation System]
    │   ├── animation_easing.v # Easing functions (ease-in, ease-out, etc.)
    │   ├── animation_spring.v # Spring physics animation
    │   ├── animation_tween.v # Property tween animations
    │   ├── animation_keyframe.v # Keyframe-based animations
    │   ├── animation_layout.v # Layout transition animations
    │   └── animation_hero.v # Hero (shared) element animations
    │
    ├── [Event System]
    │   ├── event_handlers.v # Traversal and callback execution
    │   └── event_traversal.v # Tree traversal order logic
    │
    ├── [Styling & Theme]
    │   ├── theme.v          # Theme application and color overrides
    │   ├── theme_types.v    # Theme struct definition
    │   ├── theme_defaults.v # Default light/dark theme palettes
    │   ├── sizing.v         # Sizing enum (fixed, fit, grow)
    │   ├── alignment.v      # Alignment enums (H/V alignment)
    │   ├── padding.v        # Padding struct (top/right/bottom/left)
    │   ├── float_attach.v   # FloatAttach enum (anchor points)
    │   └── fonts.v          # Font variant definitions
    │
    ├── [Rendering System]
    │   ├── shaders.v        # Shader abstraction layer
    │   ├── shaders_glsl.v   # OpenGL/GLSL shaders
    │   └── shaders_metal.v  # Metal shaders
    │
    ├── [Extra/Utility Modules]
    │   ├── xtra_text.v      # Text utilities (word wrap, selection)
    │   ├── xtra_text_cursor.v # Text cursor management
    │   ├── xtra_window.v    # Window utilities
    │   ├── xtra_image.v     # Image loading/caching
    │   ├── xtra_svg.v       # SVG parsing and caching
    │   ├── xtra_markdown.v  # Markdown parser helpers
    │   ├── xtra_mermaid.v   # Mermaid diagram rendering
    │   ├── xtra_rtf.v       # Rich Text Format parsing
    │   ├── xtra_math.v      # Math utilities (vector, bezier)
    │   └── vector.v         # Vector graphics and path utilities
    │
    ├── [Data Structures]
    │   ├── bounded_stack.v  # Fixed-size stack (for memory efficiency)
    │   └── bounded_map.v    # Fixed-size map/hash table
    │
    ├── [Utilities]
    │   ├── debug.v          # Debug utilities
    │   ├── stats.v          # Rendering statistics
    │   └── view_state.v     # ViewState struct (focus, scroll, selection)
    │
    ├── [Platform-Specific]
    │   └── titlebar.c.v     # Native C interop for window titlebar
    │
    ├── [Scripts]
    │   ├── _checkall.vsh    # Validation script
    │   ├── _doc.vsh         # Documentation generation
    │   ├── scc.sh           # Code metrics script
    │   └── examples/_*.vsh  # Example build scripts
    │
    ├── [Config & Metadata]
    │   ├── v.mod            # V module manifest
    │   ├── LICENSE          # MIT license
    │   ├── README.md        # Project overview
    │   └── gui.dylib        # Compiled dynamic library
    │
    └── [Test Files] (18 test files)
        ├── _gui_test.v
        ├── _layout_test.v
        ├── _layout_border_test.v
        ├── _render_test.v
        ├── _theme_test.v
        ├── _styles_test.v
        ├── _event_test.v
        ├── _bounded_stack_test.v
        ├── _bounded_map_test.v
        ├── _xtra_text_test.v
        ├── _xtra_math_test.v
        ├── _view_table_test.v
        ├── _markdown_test.v
        ├── _shaders_test.v
        ├── _integration_test.v
        ├── _test_fixtures.v
        └── _test_refactor.v
```

## Directory Purposes

**examples/**
- Purpose: Demonstration applications showcasing framework features
- Contains: 60+ standalone V programs, each compiled to a binary
- Key files: `buttons.v`, `showcase.v`, `markdown.v`, `table_demo.v`, `theme_designer.v`
- Notable: Each example is a self-contained demo; most use common patterns like color
configuration, layout demo, and event handling

**docs/**
- Purpose: User-facing documentation and architecture diagrams
- Contains: Markdown guides covering animation, layout algorithm, markdown rendering, tables,
performance tips, SVG support
- Key files: `ARCHITECTURE.md`, `LAYOUT_ALGORITHM.md`, `GET_STARTED.md`

**assets/**
- Purpose: Static resources (fonts, icons, themes)
- Contains: Image files and font resources for examples

**.planning/codebase/**
- Purpose: GSD analysis documents
- Contains: Architecture/structure/conventions/testing/concerns docs generated by map-codebase
- Auto-managed by orchestrator

## Key File Locations

**Entry Points:**
- `examples/get_started.v`: Minimal hello-world example
- `examples/showcase.v`: Comprehensive feature showcase (64KB)
- `examples/buttons.v`: Basic button interaction demo

**Configuration:**
- `v.mod`: Module manifest, declares dependency on vglyph
- `theme_defaults.v`: Light/dark theme color palettes
- `_gui.v`: Module-level globals (default theme, version constant)

**Core Logic:**
- `window.v`: Window lifecycle, frame loop (250+ lines)
- `layout.v`: 12-phase layout pipeline (100+ lines)
- `view.v`: View interface and generation (27 lines, foundational)
- `shape.v`: Unified shape struct (100+ lines, 80+ fields)
- `render.v`: Rendering primitives (70+ lines)

**Testing:**
- `_*_test.v`: Test files (18 total, ~300 lines combined)
- Most tests cover layout, rendering, theme, and data structures
- Integration test in `_integration_test.v`

## Naming Conventions

**Files:**
- `view_*.v`: UI component implementations (view_button.v, view_input.v)
- `animation_*.v`: Animation implementations (animation_easing.v, animation_keyframe.v)
- `layout_*.v`: Layout engine components (layout_sizing.v, layout_position.v)
- `event_*.v`: Event handling components (event_handlers.v, event_traversal.v)
- `xtra_*.v`: Utility/extra modules (xtra_text.v, xtra_svg.v)
- `_*_test.v`: Test files (underscore prefix for module-level organization)
- `theme_*.v`: Theme-related files (theme.v, theme_defaults.v, theme_types.v)
- `view_state.v`: Widget state management (focus, scroll, selection)

**Directories:**
- `examples/`: All example apps in single directory (no subdirectories)
- `docs/`: Documentation separate from code
- `.planning/codebase/`: GSD analysis outputs

## Where to Add New Code

**New View Component:**
- Implementation: Create `view_mycomponent.v` in root
- Config struct: `pub struct MyComponentCfg { ... }`
- Implementation: `struct MyComponent implements View { ... }`
- Factory: `pub fn mycomponent(cfg MyComponentCfg) View { ... }`
- Tests: `_mycomponent_test.v` (optional)
- See: `view_button.v`, `view_input.v` as templates

**New Animation Type:**
- Implementation: Create `animation_mytype.v` in root
- Struct: `pub struct MyAnimation implements Animation { ... }`
- Pattern: Follow `animation_tween.v` or `animation_keyframe.v`

**New Layout Algorithm Phase:**
- Implementation: Add function to `layout.v` or create `layout_new_phase.v`
- Integration: Call from `layout_pipeline()` in proper order
- See: `layout_sizing.v` for width/height calculation pattern

**Utility Functions:**
- String utilities: `xtra_text.v`
- Math utilities: `xtra_math.v`
- Window-specific: `xtra_window.v`
- Create new `xtra_*.v` for domain-specific utilities

**Example Applications:**
- Location: `examples/myapp.v`
- Pattern: Single file, import gui, define view generator, call gui.window() and run
- Reference: `examples/buttons.v`, `examples/inputs.v`

## Special Directories

**examples/bin/**
- Purpose: Compiled example binaries
- Generated: Yes (via build script `examples/_build.vsh`)
- Committed: No (binaries)
- Usage: Run compiled demos without recompilation

**.planning/codebase/**
- Purpose: GSD analysis output directory
- Generated: Yes (by map-codebase orchestrator)
- Committed: Yes (documents tracked in git)
- Files: ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, STACK.md,
INTEGRATIONS.md, CONCERNS.md

**_markdown_test.dSYM/**
- Purpose: Debug symbols for markdown test binary
- Generated: Yes (by compiler during debug builds)
- Committed: No

## File Organization Principles

**Cohesion by Function:**
- View components grouped by purpose (text, input, selection, dialog, etc.)
- Layout phases separated into focused files (sizing, position, query)
- Animation types separated by behavior (easing, keyframe, tween, spring)

**Single Responsibility:**
- Each view file implements one component type
- Each animation file implements one animation pattern
- Utility modules separated by domain (text, math, image, svg)

**Test Co-location:**
- Test files use `_name_test.v` convention in same directory as code
- Allows easy discovery and testing of specific modules

---

*Structure analysis: 2026-02-01*
