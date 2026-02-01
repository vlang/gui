# Project Research Summary

**Project:** v-gui multi-stop gradient support
**Domain:** GPU-accelerated UI rendering with cross-platform shaders
**Researched:** 2026-02-01
**Confidence:** HIGH

## Executive Summary

v-gui needs multi-stop gradient support for CSS-compatible UI rendering. Research shows fragment
shader approach is optimal for v-gui's sokol/sgl immediate-mode architecture. Modern UI
frameworks (Warp, Skia) use fragment shaders with procedural gradient computation or texture
sampling. For v-gui's use case (inline gradients bound to geometry, not reusable patterns),
fragment shader with uniform-based stops (MVP) scaling to texture-based (production) is
recommended.

Current implementation is vertex-color interpolation (2 stops only, HACK comment at render.v:838).
Proper implementation requires dedicated gradient pipeline following existing patterns
(shadow_pip, blur_pip) with SDF clipping for rounded corners. Linear gradients are table stakes,
radial gradients are expected, conic gradients can defer to v2+. Critical risks: color banding
without dithering, Metal/GLSL coordinate system mismatches, precision qualifier issues on mobile
GPUs.

Recommended approach: dedicated fragment shader pipeline with uniform array for 3-5 stops (MVP),
migrate to 1D texture for unlimited stops (production). Reuse existing SDF patterns for rounded
rect clipping. Implement in phases: linear multi-stop, angle/direction control, radial gradients,
border gradients. Cross-platform testing essential from day one — Metal/GLSL differences cause
silent failures.

## Key Findings

### Recommended Stack

**Fragment shader + 1D texture** is optimal for v-gui context. Modern frameworks use two
strategies: fragment-shader-based (Warp, Skia) for geometry-bound gradients, texture-atlas-based
(WebRender) for cached/reusable patterns. v-gui gradients are inline (defined per-rectangle, not
reused), making fragment shader approach best fit.

**Core technologies:**
- sokol.gfx (current) — GPU abstraction layer, cross-platform support
- sokol.sgl (current) — immediate-mode rendering wrapper
- Metal Shading Language (Metal 3+) — macOS shader implementation
- GLSL (330+) — cross-platform shader implementation
- 1D textures (gfx.make_image with .type_1d) — store gradient ramps for multi-stop interpolation

**Implementation technique:**
1. Generate 1D gradient texture (256-1024 pixels) from color stops
2. Fragment shader samples texture based on gradient position (linear: dot product projection,
   radial: distance from center)
3. Combine with existing SDF rounded rect clipping
4. Alternative for MVP: uniform array (3-5 stops) before texture implementation

### Expected Features

**Must have (table stakes):**
- Linear gradient with multi-stop (3+ stops) — core CSS feature since 2009
- Linear gradient angle/direction — CSS spec: `to bottom`, `45deg`, etc.
- Radial gradient (circle) with multi-stop — standard shape for radial gradients
- Color stop positioning — arbitrary positions (0-100%)
- Premultiplied alpha interpolation — CSS spec requirement, prevents grey artifacts
- Auto-positioned stops — evenly space stops when positions omitted
- Default behaviors — `to bottom` for linear, `farthest-corner` for radial

**Should have (competitive):**
- Radial gradient ellipse — axis-aligned ellipses (CSS default shape)
- Radial gradient size keywords — `closest-side`, `farthest-corner`, etc.
- Radial gradient position — `at 40px 40px`, `at top left`
- Transition hints — midpoint control between stops
- Multi-position color stops — hard color transitions: `red 50% 60%`
- Direction keywords — `to left top`, `to right`, etc.

**Defer (v2+):**
- Conic gradients — newer (2020), niche use cases (pie charts, color wheels)
- Repeating gradients — uncommon, can use CSS repeat
- Color interpolation spaces — `in oklab`, `in hsl` (CSS Color 5, low adoption)
- Gradient animation — separate concern (animation system)

**Anti-features (do not build):**
- Border-image gradient + border-radius — CSS spec incompatibility (no effect together)
- Texture-based gradients (for MVP) — fragment shader approach is better
- Complex color space conversions — stick to sRGB premultiplied alpha

### Architecture Approach

Create dedicated gradient pipeline following existing v-gui shader pattern. v-gui uses 3-stage
rendering: View generation → Layout calculation → Render. Gradients already flow through this
pipeline via Gradient struct → DrawGradient renderer → draw_gradient_rect(). Current
implementation uses existing rounded_rect_pip with vertex color interpolation (limited to 2
stops).

**Major components:**

1. **Gradient Pipeline (new)** — dedicated sokol.sgl pipeline with fragment shader for multi-stop
   computation. Follows shadow_pip/blur_pip pattern: pipeline initialization in shaders.v,
   shader code in shaders_metal.v/shaders_glsl.v
2. **Gradient Data Transmission** — pass stops to GPU via uniform array (MVP: 3-5 stops in tm
   matrix) or 1D texture (production: 256+ stops). Reuse existing parameter packing pattern
   (z-coordinate for radius/flags)
3. **Fragment Shader Logic** — compute SDF for rounded rect clipping, calculate gradient position
   based on UV coordinates and gradient type, interpolate color across stops, output
   gradient_color * sdf_alpha
4. **Integration** — modify draw_gradient_rect() to use new pipeline instead of vertex
   interpolation. Keep existing function signature, swap implementation

**Key patterns to follow:**
- Pipeline isolation — dedicated pipeline per effect (shadow_pip, blur_pip, gradient_pip)
- Parameter packing — z-coordinate for per-primitive params (radius, stop_count)
- Matrix smuggling — tm uniform for auxiliary data (gradient direction, stop data)
- SDF composition — combine gradient computation with rounded_box_sdf for clipping
- Lazy initialization — init_gradient_pipeline() checks window.gradient_pip_init flag

### Critical Pitfalls

1. **Color banding without dithering** — 8-bit color shows visible "bands" in gradients. Add
   dithering in fragment shader before quantization: `dither = (random(gl_FragCoord.xy) - 0.5) /
   255.0; fragColor.rgb += vec3(dither);` Must happen in fragment shader where full precision
   available, not post-processing.

2. **Metal/GLSL coordinate system mismatch** — GLSL uses bottom-left origin (0,0), Metal uses
   top-left. Gradients render upside-down on one platform without correction. Use sokol-shdc
   platform options: `@msl_options flip_vert_y` and `@glsl_options fixup_clipspace`. Test on
   both Metal (macOS) and OpenGL (Linux) from day one.

3. **Precision qualifiers missing** — mobile/integrated GPUs fail without explicit precision
   declarations. Desktop GPUs ignore qualifiers (use highp everywhere), mobile GPUs honor them.
   Declare `precision mediump float;` at shader top, use highp only where needed with fallback.
   Test on actual mobile hardware — desktop emulation won't catch this.

4. **sokol-shdc binding annotation mismatches** — vertex/fragment shader input/output mismatches
   cause compilation errors in one backend but not others. Follow binding rules: explicit
   `layout(binding=N)` for uniform blocks, unique bindings within type across stages, remove
   unused vertex shader outputs.

5. **Procedural gradient computation bottleneck** — per-pixel calculation (10-50+ shader
   instructions) overwhelms GPU with many gradients. Hybrid approach: generate gradient texture
   once, sample in fragment shader (leverages hardware filtering). For MVP: optimize procedural
   with uniform array, migrate to texture if profiling shows bottleneck.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Linear Gradient Foundation (Uniform-Based MVP)
**Rationale:** Replace vertex interpolation with fragment shader, prove architecture works before
adding complexity. Uniform array supports 3-5 stops (sufficient for most UI gradients) without
texture implementation overhead.

**Delivers:** Multi-stop linear gradients (3-5 stops) with arbitrary positioning

**Addresses:**
- Table stakes: multi-stop interpolation, color stop positioning, auto-positioned stops
- Architecture: dedicated gradient pipeline, fragment shader integration
- Current limitation: replaces HACK at render.v:838

**Avoids:**
- Pitfall 1: Add dithering from start
- Pitfall 2: Configure sokol-shdc platform options before first compile
- Pitfall 3: Declare precision qualifiers in initial shader template
- Pitfall 4: Follow binding annotation rules

**Stack elements:**
- sokol.sgl custom pipeline (pattern: shadow_pip)
- Metal/GLSL fragment shaders (new: gradient computation)
- Uniform array for stops (tm matrix parameter packing)

### Phase 2: Linear Gradient Direction Control
**Rationale:** Direction/angle support is table stakes for CSS compatibility. Builds on Phase 1
fragment shader foundation, adds gradient line calculation.

**Delivers:** Arbitrary linear gradient angles (horizontal, vertical, diagonal, arbitrary degrees)

**Addresses:**
- Table stakes: angle/direction support (`to bottom`, `45deg`)
- Features: direction keywords (`to left top`, `to right`)

**Uses:**
- Phase 1 pipeline with added direction vector uniform
- Fragment shader: dot product projection onto gradient axis

**Avoids:**
- Pitfall 8: Guard math operations (NaN from edge cases)

### Phase 3: Radial Gradient Support
**Rationale:** Radial gradients are expected feature, parallel to linear. Fragment shader branches
on gradient type, computes distance instead of projection.

**Delivers:** Circular radial gradients with multi-stop interpolation

**Addresses:**
- Table stakes: radial gradient (circle), multi-stop interpolation
- Should-have: radial position (`at 50% 50%`)

**Implements:**
- Architecture: radial gradient computation in fragment shader
- Stack: reuse 1D texture approach, different sampling coordinate calculation

**Avoids:**
- Pitfall 7: Include early fragment discard or bounds optimization for overdraw
- Pitfall 9: Avoid unnecessary normalization in distance calculations

### Phase 4: Texture-Based Stops (Production Scaling)
**Rationale:** Unlimited stops for complex gradients, better performance than procedural for many
stops. Validate need via profiling Phase 1-3 before implementing.

**Delivers:** Support for 10+ gradient stops efficiently

**Addresses:**
- Performance: texture sampling faster than loops for many stops
- Flexibility: remove uniform array stop limit

**Uses:**
- sokol.gfx 1D texture creation (gfx.make_image with .type_1d)
- Fragment shader: texture sampling instead of uniform array

**Avoids:**
- Pitfall 5: Texture approach mitigates procedural bottleneck

### Phase 5: Border Gradients
**Rationale:** Border gradients less common but needed for full CSS compatibility. Requires stroke
SDF logic, more complex than fill gradients.

**Delivers:** Linear and radial gradients on borders

**Addresses:**
- Should-have: gradient border support
- Workaround: border-radius incompatibility (CSS spec limitation)

**Uses:**
- Phase 1-3 gradient computation logic
- Architecture: stroke SDF (abs(d + thickness*0.5) - thickness*0.5)

### Phase Ordering Rationale

- **Foundation-first:** Phase 1 establishes pipeline architecture before feature expansion
- **Incremental complexity:** Linear → direction → radial → texture → border
- **Validation points:** Each phase delivers working feature, can ship independently
- **Risk mitigation:** Critical pitfalls addressed in Phase 1 (dithering, coordinate systems,
  precision) before architecture locked in
- **Performance gating:** Phase 4 (texture) optional based on Phase 1-3 profiling results

### Research Flags

**Needs deeper research during planning:**
- Phase 4 (texture-based) — needs profiling of Phase 1-3 to validate necessity, texture cache
  strategy unclear
- Phase 5 (border gradients) — border-radius incompatibility needs workaround design, research
  CSS community solutions

**Standard patterns (skip research-phase):**
- Phase 1 (linear MVP) — well-documented fragment shader approach, established pattern
- Phase 2 (direction control) — CSS spec defines algorithm, math straightforward
- Phase 3 (radial) — parallel to linear, distance calculation standard

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Fragment shader approach matches v-gui architecture, proven in Warp/Skia. sokol.sgl integration proven by existing shadow/blur pipelines |
| Features | HIGH | CSS gradient spec authoritative source, clear table stakes vs optional features |
| Architecture | HIGH | Dedicated pipeline pattern established in codebase (shadow_pip, blur_pip). SDF clipping proven technique |
| Pitfalls | MEDIUM-HIGH | Well-documented issues (banding, coordinates, precision) HIGH confidence. sokol-shdc specifics MEDIUM (less direct examples, generalized from docs) |

**Overall confidence:** HIGH

Research is specific, actionable, and proven by modern frameworks. Fragment shader + 1D texture
approach is optimal for v-gui's immediate-mode context with inline gradients.

### Gaps to Address

**During Phase 1 planning:**
- Exact uniform array packing strategy for 3-5 stops in tm matrix — need to validate float count
  limits
- sokol-shdc binding annotations for gradient pipeline — follow docs but test both backends early

**During Phase 4 planning (if needed):**
- Texture caching strategy — when to regenerate vs reuse 1D textures for identical gradients
- Texture resolution vs quality trade-off — 256 vs 512 vs 1024 pixels, configurable or fixed

**During Phase 5 planning:**
- Border-radius + gradient workaround approach — dual background vs pseudo-element vs mask
- Stroke SDF integration with existing border rendering

**Cross-platform validation:**
- Mobile GPU testing — precision qualifier behavior on actual Android/iOS devices (not emulators)
- sokol-shdc with V language bindings — minimal examples found, may need experimentation

## Sources

### Primary (HIGH confidence)
- [MTLDoc: Shaders Explained - Gradients](https://mtldoc.com/metal/2022/08/04/shaders-explained-gradients) — Metal gradient shader patterns, authoritative
- [Warp: How to Draw Styled Rectangles Using GPU and Metal](https://www.warp.dev/blog/how-to-draw-styled-rectangles-using-the-gpu-and-metal) — Production gradient implementation
- [MDN: CSS linear-gradient()](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/gradient/linear-gradient) — Official CSS spec
- [MDN: CSS radial-gradient()](https://developer.mozilla.org/en-US/docs/Web/CSS/gradient/radial-gradient) — Official CSS spec
- [W3C: CSS Images Module Level 3](https://www.w3.org/TR/css-images-3/) — Gradient interpolation algorithms
- [WebGL Precision Issues](https://webglfundamentals.org/webgl/lessons/webgl-precision-issues.html) — Mobile GPU precision
- [Shader Advanced: Color Banding and Dithering](https://shader-tutorial.dev/advanced/color-banding-dithering/) — Dithering techniques

### Secondary (MEDIUM confidence)
- [WebRender: Eight Million Pixels - GUIs on GPU](https://nical.github.io/drafts/gui-gpu-notes.html) — Texture atlas approach
- [WebGL gradient implementation guide](https://alexharri.com/blog/webgl-gradients) — Multi-stop shader implementation
- [sokol-shdc documentation](https://github.com/floooh/sokol-tools/blob/master/docs/sokol-shdc.md) — Cross-compilation annotations
- [Navigating Coordinate System Differences](https://www.realtech-vr.com/navigating-coordinate-system-differences-in-metal-direct3d-and-opengl-vulkan/) — Platform differences
- v-gui codebase (render.v:838 HACK, shaders.v pipeline patterns) — Existing architecture

### Tertiary (LOW confidence, needs validation)
- [nanovg multi-stop gradients PR](https://github.com/memononen/nanovg/pull/430) — Texture vs uniform discussion
- [Border gradient + radius workarounds](https://dev.to/afif/border-with-gradient-and-radius-387f) — Community solutions for Phase 5

---
*Research completed: 2026-02-01*
*Ready for roadmap: yes*
