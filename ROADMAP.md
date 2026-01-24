# Roadmap

This roadmap outlines the strategic direction for `v-gui`, focusing on enhancing its capabilities as a
cross-platform, immediate mode GUI toolkit.

## Toolkit Analysis

### Strengths
- **Simplicity:** The pure V implementation eliminates complex build chains and C++ interoperability
  headaches common in other toolkits.
- **Immediate Mode:** The "data-first" approach simplifies state management, avoiding the "sync"
  problems (observables, data binding) of retained mode systems like Qt or WPF.
- **Performance:** Lightweight architecture with minimal memory overhead compared to browser-based
  (Electron) or VM-based (Java/Flutter) solutions.
- **Modern Layout:** The Flexbox-inspired layout engine is intuitive for web developers.

### Weaknesses / Opportunities
- **Rendering:** Using basic 2D primitives (`gg`/`sokol`) limits advanced visual effects
  (shadows, blurs, glassmorphism) compared to Compose or Flutter.
- **Accessibility:** Currently "Work in Progress". This is a critical barrier for adoption in
  enterprise or government software.
- **Mobile Support:** Event handling is mouse/keyboard centric. Mobile gestures (swipe, pinch) and
  behaviors (soft keyboard handling) need integrated support.
- **Ecosystem:** Fewer ready-made high-level components (Charts, DataGrids) compared to mature
  frameworks.

---

## 2026 Roadmap

### Phase 1: Core Rendering & Visual Polish
*Focus: Matching the "premium" look of modern UI frameworks.*

- [ ] **Advanced Shaders:** Implement `sgl` pipelines for:
    - Drop shadows (box-shadow)
    - Gaussian blur (background blur for glass effects)
    - Gradient borders and complex fills
- [ ] **Animation System 2.0:**
    - Add physics-based spring animations (more natural than linear/easing curves).
    - Support layout transitions (animated constraints when window resizes).
    - Add "hero" transitions between views.
- [ ] **Vector Graphics:** Better integration for SVG icons or path-based drawing beyond simple
       shapes.

### Phase 2: Fundamental Widgets & UX
*Focus: Completing the standard library of widgets expected by developers.*

- [ ] **Navigation Components:**
    - **Tabs:** A flexible tab bar and view switcher.
    - **Breadcrumbs:** For navigational hierarchy.
    - **Drawer:** Slide-out navigation menu (essential for mobile).
- [ ] **Feedback & Overlays:**
    - **Toast/Snackbar:** Non-modal notifications.
    - **Modal Logic:** Refine the dialog system to support stacked modals and custom backdrops.
    - **Tooltip:** Enhance with rich content support (not just text).
- [ ] **Data Display:**
    - **DataGrid:** A performant table with sorting, filtering, and column resizing (expanding on
      `view_table.v`).
    - **TreeGrid:** Hierarchical data combined with column data.
    - **Charting:**
        - **Basic Charts:** Line, Bar, Pie, and Area charts.
        - **Interactivity:** Tooltips on hover, legend toggling, and zooming.
- [ ] **Rich Content:**
    - **Markdown View:** Render rich text from markdown source (headers, lists, code blocks).
    - **Code Editor Widget:**
        - **Syntax Highlighting:** Tokenizer rendering pipeline.
        - **Gutter:** Line numbers and active line highlighting.
        - **Virtualization:** Efficient rendering of large documents (only visible lines).



### Phase 3: Accessibility & I18n
*Focus: Professional readiness and compliance.*

- [ ] **Accessibility (A11y) Tree:**
    - Map `View` hierarchy to platform A11y APIs (NSAccessibility, UIAutomation, AT-SPI).
    - ensure semantic roles (Button, Slider, List) are correctly exposed.
    - Support focus navigation order customization.
- [ ] **Internationalization (I18n):**
    - Built-in `tr()` support in views.
    - Dynamic directionality (RTL/LTR) flipping based on locale.
    - Date/Number formatting utilities integrated with input widgets.

### Phase 4: Platform & Input
*Focus: Breaking out of the "desktop" box.*

- [ ] **Touch & Gestures:**
    - Abstraction for Pointers (Mouse/Touch/Pen).
    - Recognizers for: Swipe, Pinch, Long Press, Double Tap.
    - Kinetic scrolling for lists (physics-based fling).
- [ ] **Mobile Integration:**
    - Handle safe areas (notch/dynamic island).
    - Soft keyboard visibility management (resize window vs overlay).
- [ ] **OS Integration:**
    - Native File Dialogs (if not fully covered).
    - System Tray support.
    - Badge counts app icon.

### Phase 5: Developer Experience (DX)
*Focus: Making `v-gui` a joy to use.*

- [ ] **Inspector Tool:** An in-app debug overlay (similar to Flutter Inspector) to:
    - Visualize layout bounds/padding/margins.
    - Pick widgets and see their state.
    - View performance metrics per-widget.
- [ ] **Theme System Upgrade:**
    - Support "Design Tokens" for easy mapping from Figma.
    - Runtime theme switching (Dark/Light/High Contrast) without app restart.

## Comparison Table

| Feature | v-gui | Flutter | Dear ImGui |
| :--- | :--- | :--- | :--- |
| **Paradigm** | Immediate (Clay-based) | Retained (Widget Tree) | Immediate |
| **Language** | V | Dart | C++ |
| **Layout** | Flexbox-like | Flexbox-like | Linear / Columns |
| **Rendering** | Sokol/GG | Skia/Impeller | Custom OpenGL |
| **State** | User-managed (Simple) | Widget-managed (Complex) | User-managed |
| **Styling** | Code-defined | Widget-composition | Global Styles |

## Summary
`v-gui` is well-positioned as a simplified, high-performance alternative to Flutter for V
developers.
The immediate priority should be **Rendering Fidelity** (shadows/blur) and **Accessibility** to
validate it for production desktop apps, before expanding fully into mobile.
