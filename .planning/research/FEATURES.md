# CSS Gradient Feature Landscape

**Domain:** CSS-compatible gradient rendering in GUI framework
**Researched:** 2026-02-01
**Confidence:** HIGH

## Executive Summary

CSS gradients split into 3 types: linear, radial, conic. Linear and radial are table stakes for CSS
compatibility. Conic gradients (pie charts, color wheels) are newer (2020) and less critical.
Multi-stop interpolation with premultiplied alpha is essential. Transition hints (midpoint control)
are widely used. Repeating gradients are niche. Border gradients need workarounds due to
border-radius incompatibility.

## Table Stakes Features

Must-have for CSS gradient compatibility. Missing = incomplete implementation.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Linear gradient: multi-stop** | Core CSS feature, baseline since 2009 | Medium | Currently HACK in v-gui (render.v:838), only 2-color |
| **Linear gradient: angle/direction** | CSS spec: `to bottom`, `45deg`, etc. | Low-Med | Need gradient line calculation |
| **Radial gradient: circle** | Standard shape for radial gradients | Medium | Circular with single radius |
| **Radial gradient: multi-stop** | Parallel to linear multi-stop | Medium | Same interpolation as linear |
| **Color stop positioning** | Arbitrary positions (0-100%) | Low | Already in Gradient struct (pos field) |
| **Premultiplied alpha interpolation** | CSS spec requirement, prevents grey artifacts | Medium | Required for rgba() transitions to transparent |
| **Auto-positioned stops** | Evenly space stops when positions omitted | Low | Calculate positions: 0%, 50%, 100%, etc. |
| **Default behaviors** | `to bottom` for linear, `farthest-corner` for radial | Low | Sensible defaults match CSS |

## Differentiators

Features that enhance gradient capability. Not baseline but widely used.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Radial gradient: ellipse** | Axis-aligned ellipses (CSS default shape) | Medium-High | Dual radii, more complex than circle |
| **Radial gradient: size keywords** | `closest-side`, `farthest-corner`, etc. | Medium | CSS spec defines 4 keywords |
| **Radial gradient: position** | `at 40px 40px`, `at top left` | Low-Med | Center point placement |
| **Transition hints (color hints)** | Midpoint control between stops | Medium | Unlabeled % between stops, non-linear interpolation |
| **Multi-position color stops** | Hard color transitions (solid bands) | Low | Same stop at 2 positions: `red 50% 60%` |
| **Direction keywords** | `to left top`, `to right`, etc. | Low | 8 compass directions + 4 sides |

## Advanced/Optional Features

Features that add polish but can defer to v2+.

| Feature | Value | Complexity | Defer Rationale |
|---------|-------|------------|-----------------|
| **Conic gradients** | Pie charts, color wheels | Medium-High | Newer (2020), niche use cases |
| **Repeating gradients** | Striped patterns | Low-Med | Uncommon, can use CSS repeat |
| **Color interpolation spaces** | `in oklab`, `in hsl`, etc. | High | Modern spec (CSS Color 5), low adoption |
| **Hue interpolation methods** | `shorter hue`, `longer hue`, etc. | High | Polar color space complexity |
| **Out-of-order positions** | Handles `red 40%, yellow 30%` | Low | Edge case, minimal value |
| **Gradient animation** | Animated color stops | Medium | Separate concern (animation system) |

## Anti-Features

Features to explicitly NOT build for v1. Common mistakes or out-of-scope.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Border-image gradient + border-radius** | CSS spec incompatibility (no effect together) | Use workaround: dual background or pseudo-element approach |
| **Texture-based gradients** | Performance overhead, limited flexibility | Fragment shader approach for multi-stop |
| **Complex color space conversions** | Pre-2025 feature, low ROI | Stick to sRGB premultiplied alpha |
| **1D texture sampling** | GPU texture overhead | Calculate in fragment shader directly |
| **Single-color gradients** | Degenerates to solid color | Validate: require min 2 stops |

## Feature Dependencies

```
Color Stop Foundation
├── Multi-stop interpolation (required for everything)
│   ├── Premultiplied alpha (required for rgba support)
│   └── Auto-positioning (defaults)
│
├── Linear Gradients
│   ├── Angle/direction (required)
│   ├── Transition hints (optional enhancement)
│   └── Multi-position stops (optional hard transitions)
│
└── Radial Gradients
    ├── Circle shape (required)
    ├── Ellipse shape (optional, more complex)
    ├── Position (required, default=center)
    └── Size keywords (optional, default=farthest-corner)
```

## v1 MVP Recommendation

**Phase 1: Multi-stop linear gradients**
- Multi-stop color interpolation (3+ stops)
- Arbitrary color stop positioning (0-100%)
- Premultiplied alpha blending
- Auto-positioned stops (evenly spaced)
- Default direction (`to bottom`)

**Phase 2: Linear gradient directions**
- Angle support (`45deg`, `0.25turn`)
- Direction keywords (`to left`, `to top right`)
- Gradient line length calculation

**Phase 3: Radial gradients (circle)**
- Circle shape with single radius
- Multi-stop interpolation (reuse from linear)
- Position (`at 50% 50%`)
- Default size (`farthest-corner`)

**Phase 4: Border gradients**
- Linear border gradients
- Workaround for border-radius incompatibility
- Radial border gradients (if time)

**Defer to v2+:**
- Transition hints (color hints): LOW priority, enhancement
- Radial ellipse: MEDIUM priority, more complex
- Radial size keywords: LOW priority, default is sufficient
- Conic gradients: LOW priority, niche
- Repeating gradients: LOW priority, uncommon

## Complexity Breakdown

| Feature Category | Implementation Effort | Risk |
|------------------|---------------------|------|
| Multi-stop linear | Medium (shader work) | Low (well-documented) |
| Angle/direction | Low-Medium (math) | Low (CSS spec clear) |
| Radial circle | Medium (different shader) | Medium (ellipse math) |
| Radial ellipse | High (complex shader) | Medium (edge cases) |
| Border gradients | Medium (rendering approach) | High (border-radius conflict) |
| Conic gradients | High (new shader type) | Medium (less common, fewer refs) |
| Transition hints | Medium (non-linear interpolation) | Low (CSS algorithm defined) |

## Current v-gui State

**Implemented (partial):**
- 2-color linear gradient via vertex color interpolation (HACK at render.v:838)
- Gradient struct with stops array (styles.v:33-41)
- GradientType enum (.linear, .radial) (styles.v:22-25)
- Border gradient placeholders (ContainerStyle, RectangleStyle)

**Limitations:**
- Only 2 stops work correctly (vertex interpolation)
- Only horizontal linear gradients work
- No angle/direction support
- No radial gradient implementation
- Border gradients not functional

**Infrastructure:**
- Shader pipeline exists (shaders_metal.v, shaders_glsl.v)
- Rounded rect pipeline (render.v:831)
- Cross-platform shader support (Metal/GLSL)

## Implementation Strategy Recommendation

**Fragment shader approach (recommended):**
- Calculate gradient value per-pixel in fragment shader
- Supports arbitrary number of stops
- Handles premultiplied alpha correctly
- Performance: GPU-native, parallel

**Vertex color interpolation (current approach):**
- Limited to 4 colors (quad corners)
- Cannot handle 3+ stops accurately
- Simple but insufficient for CSS compatibility

**Texture-based approach (not recommended):**
- Generate 1D texture with gradient colors
- Sample texture in shader
- Overhead: texture upload, memory
- Inflexible: requires regeneration for changes

## Sources

**HIGH confidence sources:**
- [linear-gradient() - MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/gradient/linear-gradient) - Official CSS spec
- [radial-gradient() - MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/gradient/radial-gradient) - Official CSS spec
- [conic-gradient() - MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/gradient/conic-gradient) - Official CSS spec
- [CSS Images Module Level 3](https://www.w3.org/TR/css-images-3/) - W3C gradient spec (interpolation algorithms)
- [WebGL gradient implementation guide](https://alexharri.com/blog/webgl-gradients) - Technical shader implementation

**MEDIUM confidence sources:**
- [Border gradient + radius workarounds](https://dev.to/afif/border-with-gradient-and-radius-387f) - Community solutions
- [CSS gradient usage guide](https://elementor.com/blog/css-gradients/) - 2026 practical guide
- [Premultiplied alpha in gradients](https://bugzilla.mozilla.org/show_bug.cgi?id=591600) - Browser implementation notes

**Context:**
- v-gui codebase (render.v:838 HACK, styles.v Gradient struct)
- PROJECT.md requirements
