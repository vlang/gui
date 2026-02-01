# Technology Stack

**Analysis Date:** 2026-02-01

## Languages

**Primary:**
- V (1.0+) - Entire framework and module written in V

**Secondary:**
- C (inline shaders) - Metal and GLSL shader implementations in `shaders_metal.v` and
  `shaders_glsl.v`

## Runtime

**Environment:**
- V language runtime (v1.0+)
- Targets desktop platforms (macOS, Linux, Windows via Sokol)

**Build:**
- V compiler (integrated build system)
- No external build tool needed; compile with `v gui.v` or via `v install gui`

## Frameworks

**Core Rendering:**
- `sokol` (V's Sokol bindings) - Low-level graphics API abstraction
  - `sokol.sapp` - Window management, event handling, app lifecycle
  - `sokol.gfx` - Graphics rendering (optional; primarily used via `gg`)
  - `sokol.sgl` - Immediate-mode graphics (used for custom pipelines)
- `gg` - 2D graphics context and drawing primitives
  - Part of V standard library
  - Provides Color, Image, Rect types and drawing functions

**Text Rendering:**
- `vglyph` - Advanced text system with Pango integration
  - Subpixel positioning, hinting, Unicode, OpenType, ligatures, emoji
  - Bidirectional text support
  - RichText with mixed styles

**Image Processing:**
- `stbi` - Image loading/saving and resizing (used in `xtra_mermaid.v`)
  - In-memory PNG/JPG loading via `stbi.load_from_memory()`
  - PNG writing via `stbi.stbi_write_png()`

## Key Dependencies

**Critical (declared in v.mod):**
- `vglyph` [latest] - Required for text rendering
  - Dependency: `gg` (V stdlib)
  - Dependency: `sokol.sapp` (V stdlib)

**Internal V Standard Library Used:**
- `gg` - Graphics context and drawing
- `sokol` - Cross-platform windowing and graphics
  - `sokol.sapp` - Application/window lifecycle
  - `sokol.gfx` - Graphics API (Metal/GLSL/WebGL)
  - `sokol.sgl` - Immediate-mode graphics API
- `stbi` - Image codec (PNG, JPG, BMP, etc.)
- `crypto.md5` - MD5 hashing (used in tests)
- `hash.fnv1a` - Fast hashing for caching

**Standard Library Modules (No External Deps):**
- `arrays` - Array utilities
- `clipboard` - Clipboard access
- `datatypes` - Collection types
- `encoding.csv` - CSV parsing (used in table widget)
- `encoding.utf8` - UTF-8 handling
- `math` - Math functions
- `net.http` - HTTP client (used in `xtra_mermaid.v` for Kroki API)
- `os` - File/directory operations
- `rand` - Random number generation
- `strings` - String utilities
- `sync` - Thread synchronization (Mutex)
- `time` - Time utilities

## Configuration

**Environment:**
- No required environment variables
- Window title, dimensions, and theme set via `WindowCfg` struct
- Default color theme: `gui_theme` global variable

**Build:**
- No special build configuration needed
- Compiles as single `gui.v` module
- Produces `.dylib` (macOS), `.so` (Linux), or `.dll` (Windows) when compiled

## Platform Requirements

**Development:**
- V 1.0+ compiler installed
- V language tooling (`v install gui` handles dependency resolution)
- C compiler for backend (Clang/GCC on Linux/macOS, MSVC on Windows)

**Runtime:**
- macOS: Native windowing via Sokol (Metal graphics API)
- Linux: X11 or Wayland (GLSL graphics via OpenGL/Vulkan)
- Windows: Native windowing (GLSL/DirectX via Sokol)
- Graphics hardware supporting OpenGL 3.3+, Metal, or equivalent

**Optional External Service:**
- Kroki API (`https://kroki.io`) - Used for Mermaid diagram rendering (in
  `xtra_mermaid.v`)
  - Diagram source sent to API for PNG conversion
  - Responses cached locally (max 50 entries)
  - Network timeout: No explicit timeout (uses V's http.fetch default)

---

*Stack analysis: 2026-02-01*
