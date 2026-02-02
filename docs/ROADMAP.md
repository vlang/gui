# Roadmap

This document outlines the strategic vision for `v-gui`, aiming to establish it as the premier high-performance, cross-platform UI toolkit for the V language. Our goal is to combine the simplicity of immediate mode with the visual fidelity and accessibility of retained mode frameworks.

## Strategic Pillars

1.  **Rendering Excellence:** Leverage GPU acceleration (`sgl`/`gg`) to achieve 120fps animations, glassmorphism, and advanced effects that rival Flutter's Impeller.
2.  **Accessibility First:** Integrated support for platform accessibility APIs (A11y) to serve all users, a non-negotiable requirement for modern software.
3.  **Cross-Platform Native:** Seamless execution on macOS, Windows, Linux, with experimental support for Mobile (iOS/Android) and Web (Wasm).
4.  **Developer Joy:** Zero-config tooling, hot-reload capabilities, and a comprehensive widget standard library.

---

## 2026-2027 Roadmap

### Phase 1: Core Fidelity & Widget Completeness (Q1-Q2 2026)
*Focus: Polishing the desktop experience to "Premium" standards.*

#### Rendering & Visuals
- [x] **Advanced Shadows:** Box-shadow implementation with spread/blur radius.
- [x] **Blur Effects:** Background blur (frosted glass) support.
- [ ] **Custom Shaders:** User-exposed API for fragment shaders on specific views.
- [ ] **Vector Graphics:** Complete SVG compliance (interactions, masking).

#### Essential Widgets
- [ ] **Navigation:**
    - `TabControl` (Closeable tabs, draggable reordering).
    - `BreadcrumbBar` (Path navigation).
    - `NavigationDrawer` (Collapsible sidebar with animation).
- [ ] **Overlays:**
    - `Toast` (Non-blocking notifications).
    - `Modal` (Stacked dialog architecture with backdrop management).
    - `CommandPalette` (Quick action search interface, e.g., Cmd+K).
- [ ] **Rich Content:**
    - `RichTextEditor` (Selection, copy/paste, bold/italic keybinds).
    - `CodeEditor` (Syntax highlighting, line numbers, folding).

#### Windowing & System
- [ ] **Multi-Window Support:** Spawning secondary windows from the main app.
- [ ] **System Tray:** Cross-platform tray icons and menus.
- [ ] **Drag & Drop:** OS-level drag and drop (files, data) between apps.

### Phase 2: Professional Grade (Q3-Q4 2026)
*Focus: Essential features for enterprise and commercial adoption.*

#### Accessibility (A11y)
- [ ] **A11y Tree Generation:** Map internal View hierarchy to platform accessibility trees (NSAccessibility, UIAutomation, AT-SPI).
- [ ] **Screen Reader Support:** Semantic announcements for state changes and navigation.
- [ ] **Keyboard Navigation:** Full focus management network, tab loops, and visual focus rings.

#### Internationalization (I18n)
- [ ] **Locale Awareness:** Runtime language switching.
- [ ] **RTL Support:** Bi-directional text layout and interface mirroring for right-to-left languages (Arabic, Hebrew).
- [ ] **Formatting:** Locale-specific date, number, and currency input masks.

#### Ecosystem & Tools
- [ ] **Inspector Tool:** Runtime debugging overlay to inspect view bounds, padding, and state.
- [ ] **Live Preview:** Hot-reload style development workflow.
- [ ] **Component Gallery:** A reference application showcasing all widgets and states.

### Phase 3: Ubiquity (2027+)
*Focus: Expanding beyond the desktop.*

#### Mobile (iOS/Android)
- [ ] **Touch System:** Abstraction for multi-touch pointers, gestures (Pinch, Rotation, Swipe).
- [ ] **Kinetic Scrolling:** Physics-based fling scrolling with platform-specific friction.
- [ ] **Safe Areas:** Handling notches, dynamic islands, and system bars.
- [ ] **Virtual Keyboard:** Soft keyboard management (panning view on focus).

#### Web (Wasm)
- [ ] **Web Integration:** Canvas-based rendering target.
- [ ] **Clipboard/History:** Browser API integration.

---

## Competitive Analysis

| Feature | v-gui | Flutter | Tauri | Qt |
| :--- | :--- | :--- | :--- | :--- |
| **Language** | V | Dart | Rust (Backend) + JS/HTML | C++ / Python |
| **Architecture** | Immediate Mode (Custom) | Retained Mode (Skia/Impeller) | Webview Wrapper | Retained (QPainter/Scenegraph) |
| **Binary Size** | Tiny (<5MB) | Medium (~20MB) | Small (<10MB) | Large (>40MB) |
| **Startup Time** | Instant | Fast | Medium (WebView initialization) | Medium |
| **Accessibility** | 🚧 Planned | ✅ Excellent | ✅ Native (Browser) | ✅ Mature |
| **Look & Feel** | Drawn (Customizable) | Drawn (Material/Cupertino) | Native/Web | Native (Widgets) or Custom (QML) |
| **Hot Reload** | 🚧 Varies | ✅ State-preserving | ✅ Web Frontend Only | ⚠️ Limited (QML) |

## Summary

`v-gui` aims to fill the niche of a **lightweight, dependency-free** UI framework that doesn't compromise on modern aesthetics. While frameworks like Tauri rely on heavy webviews and Flutter carries a VM, `v-gui` offers a direct-to-metal approach ideal for resource-constrained environments and developers seeking pure performance. The immediate roadmap prioritizes **Accessibility** and **Rich Text** to satisfy the baseline requirements of modern application development.
