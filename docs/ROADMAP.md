# Roadmap

This document outlines the strategic vision for `v-gui`, aiming to establish it as the
premier high-performance, cross-platform UI toolkit for the V language. Combines the
simplicity of immediate mode with the visual fidelity and accessibility of retained mode
frameworks.

## Strategic Pillars

1.  **Rendering Excellence:** GPU acceleration (`sgl`/`gg`) for 120fps animations,
    glassmorphism, and advanced effects rivaling Flutter's Impeller.
2.  **Accessibility First:** Integrated support for platform accessibility APIs (A11y)
    to serve all users.
3.  **Cross-Platform Native:** Seamless execution on macOS, Windows, Linux, with
    experimental support for Mobile (iOS/Android) and Web (Wasm).
4.  **Developer Joy:** Zero-config tooling, hot-reload capabilities, and a comprehensive
    widget standard library.

---

## Implemented

Features already shipped and available in the current codebase.

### Core Architecture
- [x] **Immediate-mode rendering pipeline** with 60fps / 1000+ widget capacity.
- [x] **Clay-inspired flex layout engine** — row/column, fit/fill/fixed sizing,
      multi-pass pipeline.
- [x] **Floating layouts** — absolute positioning for tooltips, dialogs, menus.
- [x] **Scroll containers** — horizontal/vertical, auto/always/never visibility.

### Rendering & Visuals
- [x] **SDF shaders** for anti-aliased rounded rectangles and shadows.
- [x] **Advanced shadows** — box-shadow with spread/blur radius.
- [x] **Blur effects** — background blur (frosted glass) via multi-pass shaders.
- [x] **Gradients** — linear and radial with multiple stops and directions.
- [x] **SVG rendering** — full parser (1200+ lines) with DoS protection limits.
      Partial compliance; masking and interactions remain.
- [x] **Markdown rendering** — tables, mermaid diagrams (async via Kroki API).

### Widgets (31)
- [x] **Layout:** `column`, `row`, `canvas`, `container`, `expand_panel`,
      `rectangle`.
- [x] **Input:** `input` (single/multiline, selection, clipboard, undo/redo),
      `input_date`, `select`.
- [x] **Buttons:** `button`, `toggle`, `switch`, `radio`.
- [x] **Display:** `text` (rich text runs, wrapping modes), `rtf`, `image`
      (async loading/caching with timeout), `svg`, `markdown`.
- [x] **Data:** `table` (CSV, configurable borders), `tree`, `listbox`.
- [x] **Date/Range:** `date_picker`, `date_picker_roller`, `range_slider`.
- [x] **Overlay:** `dialog` (message/confirm/prompt/custom), `menu`, `menubar`,
      `tooltip`.
- [x] **Feedback:** `progress_bar`, `pulsar`.

### Animation System
- [x] **Tween** — value interpolation with 20+ easing curves.
- [x] **Spring** — physics-based motion with damping.
- [x] **Keyframe** — multi-point animation sequences.
- [x] **Layout transitions** — automatic position/size animation.
- [x] **Hero transitions** — element morphing between views.

### Text & Fonts
- [x] **vglyph/Pango** text shaping — complex scripts, bidi, ligatures, emoji.
- [x] **Font variants** — normal, bold, italic, mono; 6 size presets each.
- [x] **Icon font** — Feathericon with 80+ icons.
- [x] **Text cursor** — viewport tracking, line/word navigation, selection.
- [x] **IME support** — composition and commit events for CJK input.

### Theming
- [x] **Theme builder** — generate complete themes from compact config.
- [x] **Built-in themes** — dark, light, bordered variants.
- [x] **Per-component styles** — button, input, container, date picker, etc.
- [x] **Color operations** — add, subtract, multiply, opacity, Porter-Duff over.

### Events & Input
- [x] **Mouse** — click (L/M/R), move, enter, leave, scroll, drag.
- [x] **Keyboard** — down, up, char, common shortcuts (Ctrl+C/V/X/Z/A).
- [x] **Touch** — multi-touch with tool type detection (finger/stylus/eraser).
- [x] **Window** — resize, focus/unfocus, close request.
- [x] **File drop** — configurable limits on count and path length.

### Platform
- [x] **macOS, Linux, Windows** via gg/sokol.sapp.
- [x] **Windows titlebar** — dark mode via DWM API.

### Infrastructure
- [x] **21 test files** — layout, rendering, widgets, integration.
- [x] **55+ examples.**
- [x] **8 documentation guides** — architecture, layout, animations, SVG,
      markdown, tables, gradients, performance.
- [x] **Async resource loading** — threaded image downloads, mermaid rendering,
      timeouts, thread-safe command queue.
- [x] **Focus navigation** — Tab/Shift+Tab with focus ID ordering and skip
      flags.

---

## 2026-2027 Roadmap

### Phase 1: Core Fidelity & Widget Completeness (Q1-Q2 2026)
*Focus: Polishing the desktop experience to "Premium" standards.*

#### Advanced Rendering
- [ ] **Custom Shaders:** User-exposed API for fragment shaders on specific
      views.
- [ ] **SVG Compliance:** Interactions, masking, remaining SVG spec gaps.

#### Essential Widgets
- [ ] **Navigation:**
    - `TabControl` (Closeable tabs, draggable reordering).
    - `BreadcrumbBar` (Path navigation).
    - `NavigationDrawer` (Collapsible sidebar with animation).
- [ ] **Overlays:**
    - `Toast` (Non-blocking notifications).
    - `CommandPalette` (Quick action search, e.g., Cmd+K).
- [ ] **Rich Content:**
    - `RichTextEditor` (Selection, copy/paste, bold/italic keybinds).
    - `CodeEditor` (Syntax highlighting, line numbers, folding).

#### Windowing & System
- [ ] **Multi-Window Support:** Spawning secondary windows from the main app.
- [ ] **System Tray:** Cross-platform tray icons and menus.
- [ ] **Drag & Drop:** Bidirectional OS-level drag and drop between apps
      (inbound file drop already implemented).

### Phase 2: Professional Grade (Q3-Q4 2026)
*Focus: Essential features for enterprise and commercial adoption.*

#### Accessibility (A11y)
- [ ] **A11y Tree Generation:** Map View hierarchy to platform accessibility
      trees (NSAccessibility, UIAutomation, AT-SPI).
- [ ] **Screen Reader Support:** Semantic announcements for state changes and
      navigation.
- [ ] **Visual Focus Rings:** Visible focus indicators beyond current
      Tab/Shift+Tab traversal.

#### Internationalization (I18n)
- [ ] **Locale Awareness:** Runtime language switching.
- [ ] **RTL Interface Mirroring:** Layout mirroring for right-to-left languages
      (bidi text rendering already handled by vglyph/Pango).
- [ ] **Formatting:** Locale-specific date, number, and currency input masks.

#### Ecosystem & Tools
- [ ] **Inspector Tool:** Runtime debugging overlay to inspect view bounds,
      padding, and state.
- [ ] **Live Preview:** Hot-reload style development workflow.
- [ ] **Component Gallery:** Reference application showcasing all widgets and
      states.

### Phase 3: Ubiquity (2027+)
*Focus: Expanding beyond the desktop.*

#### Mobile (iOS/Android)
- [ ] **Gesture Recognition:** Pinch, rotation, swipe built on existing
      multi-touch events.
- [ ] **Kinetic Scrolling:** Physics-based fling with platform-specific
      friction (basic momentum scrolling exists).
- [ ] **Safe Areas:** Handling notches, dynamic islands, and system bars.
- [ ] **Virtual Keyboard:** Soft keyboard management (panning view on focus).

#### Web (Wasm)
- [ ] **Web Integration:** Canvas-based rendering target.
- [ ] **Clipboard/History:** Browser API integration.

---

## Competitive Analysis

| Feature | v-gui | Flutter | Tauri | Qt |
| :--- | :--- | :--- | :--- | :--- |
| **Language** | V | Dart | Rust + JS/HTML | C++ / Python |
| **Architecture** | Immediate Mode | Retained (Skia/Impeller) | Webview | Retained (QPainter) |
| **Binary Size** | Tiny (<5MB) | Medium (~20MB) | Small (<10MB) | Large (>40MB) |
| **Startup Time** | Instant | Fast | Medium | Medium |
| **Accessibility** | Partial (focus nav) | Excellent | Native (Browser) | Mature |
| **Look & Feel** | Drawn (Themed) | Drawn (Material) | Native/Web | Native or QML |
| **Hot Reload** | Varies | State-preserving | Web Frontend | Limited (QML) |

## Summary

`v-gui` fills the niche of a **lightweight, dependency-free** UI framework that doesn't
compromise on modern aesthetics. While Tauri relies on heavy webviews and Flutter carries
a VM, `v-gui` offers a direct-to-metal approach ideal for resource-constrained
environments. The immediate roadmap prioritizes **Accessibility** and **Rich Content
Editing** to satisfy baseline requirements of modern application development.
