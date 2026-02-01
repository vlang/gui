# GPU Gradient Rendering Pitfalls

**Domain:** GPU gradient rendering (linear/radial) with cross-platform shaders
**Target platforms:** Metal (macOS), GLSL (Linux/Windows)
**Framework:** sokol-shdc cross-compilation
**Researched:** 2026-02-01

## Critical Pitfalls

Mistakes that cause visual artifacts, rewrites, or platform-specific failures.

### Pitfall 1: Color Banding Without Dithering

**What goes wrong:**
Gradients show visible "bands" of color instead of smooth transitions. 8-bit color (256 shades
per channel) creates discontinuities in gradients, particularly subtle single-hue gradients.

**Why it happens:**
Rendering pipeline crunches high-precision fragment shader output (f32 per channel) down to
final output (u8 per channel in SDR). Without dithering, the quantization creates hard edges
between representable color values.

**Consequences:**
- Gradient looks stepped/blocky instead of smooth
- Particularly visible in low-contrast gradients
- Users perceive as low-quality rendering

**Prevention:**
Add dithering in fragment shader BEFORE quantization:
```glsl
// Apply noise scaled to +/- 0.5/255 (just enough to break up bands)
float dither = (random(gl_FragCoord.xy) - 0.5) / 255.0;
fragColor.rgb += vec3(dither);
```

CRITICAL: Dithering must happen where full gradient precision is available. Applying in
post-processing after 24-bit buffer won't work.

**Detection:**
View gradient on actual hardware in low-contrast scenarios (subtle grays, single-hue shifts).
Banding shows as visible steps rather than smooth transitions.

**Implementation step:**
Fragment shader implementation — add dithering before final color output.

**Confidence:** HIGH
**Sources:**
- [Shader Advanced - Color Banding and Dithering](https://shader-tutorial.dev/advanced/color-banding-dithering/)
- [How to fix color banding with dithering](https://www.anisopteragames.com/how-to-fix-color-banding-with-dithering/)

---

### Pitfall 2: Metal/GLSL Coordinate System Origin Mismatch

**What goes wrong:**
Gradients render upside-down or mirrored on Metal vs GLSL platforms. Texture coordinates have
different origins: GLSL uses bottom-left (0,0), Metal uses top-left (0,0).

**Why it happens:**
Fundamental difference in coordinate systems. When shader calculates gradient position based on
fragment coordinates or texture UVs, the Y-axis interpretation differs between platforms.

**Consequences:**
- Linear gradient angles inverted on one platform
- Radial gradient centers positioned incorrectly
- Silent failure — renders "correctly" on dev platform, breaks on others

**Prevention:**
Use sokol-shdc platform-specific options:
```glsl
@msl_options flip_vert_y      // Metal coordinate correction
@glsl_options fixup_clipspace  // OpenGL depth/clip space adjustments
```

Alternative: Normalize coordinates in shader and handle Y-inversion explicitly:
```glsl
#ifdef METAL
  vec2 uv = vec2(fragCoord.x, 1.0 - fragCoord.y);
#else
  vec2 uv = fragCoord;
#endif
```

**Detection:**
Test on both Metal (macOS) and OpenGL (Linux/Windows). Compare visual output side-by-side.
Gradient direction/position differences indicate coordinate mismatch.

**Implementation step:**
Shader cross-compilation setup — configure sokol-shdc options before first shader compile.

**Confidence:** HIGH
**Sources:**
- [Navigating Coordinate System Differences in Metal, Direct3D, and OpenGL](https://www.realtech-vr.com/navigating-coordinate-system-differences-in-metal-direct3d-and-opengl-vulkan/)
- [SwiftUI Metal Shader Tutorials + Replacement from GLSL to MSL](https://medium.com/@ikeh1024/swiftui-metal-shader-tutorials-replacement-from-glsl-to-msl-6e97b7307dc2)

---

### Pitfall 3: Precision Qualifiers Missing (Mobile GPU Failures)

**What goes wrong:**
Shaders fail to compile or produce incorrect results on mobile/integrated GPUs. Fragment
shaders assume highp (32-bit float) support, but many mobile GPUs only support mediump
(16-bit) or even lowp (9-bit) in fragment stage.

**Why it happens:**
Desktop GPUs typically use highp everywhere regardless of qualifiers. Mobile GPUs actually
honor precision qualifiers and may not support highp in fragment shaders at all (optional
feature in GLSL ES).

**Consequences:**
- Shader compilation errors on mobile: "'highp' : precision not supported in fragment shader"
- Precision artifacts: NaN/inf from overflow, incorrect gradient interpolation
- Works on dev machine (desktop GPU), fails on target devices

**Prevention:**
Always declare precision qualifiers explicitly in GLSL ES shaders:
```glsl
precision mediump float;  // Default for fragment shader

// Use highp only where necessary and with fallback
#ifdef GL_FRAGMENT_PRECISION_HIGH
  precision highp float;
#else
  precision mediump float;
#endif
```

For gradient calculations, mediump is usually sufficient. Use highp only for functions that
need it (normalize, length, distance with large values).

**Detection:**
Test on actual mobile/integrated GPU hardware. Desktop emulation won't catch this — desktop
GPUs ignore mediump and use highp anyway.

Common failures: Android 7.0 devices, Amlogic S905X (Android TV), older iOS devices.

**Implementation step:**
Initial shader development — declare precision before any shader code.

**Confidence:** HIGH
**Sources:**
- [WebGL Precision Issues](https://webglfundamentals.org/webgl/lessons/webgl-precision-issues.html)
- [When to choose highp, mediump, lowp in shaders](https://webglfundamentals.org/webgl/lessons/webgl-qna-when-to-choose-highp--mediump--lowp-in-shaders.html)
- [Optimize with reduced precision - Android](https://developer.android.com/games/optimize/vulkan-reduced-precision)

---

### Pitfall 4: sokol-shdc Binding Annotation Mismatches

**What goes wrong:**
Shader compiles in one backend but fails in another with cryptic binding errors. Vertex and
fragment shader inputs/outputs don't match, or uniform bindings conflict across stages.

**Why it happens:**
sokol-shdc requires explicit binding annotations that differ from vanilla GLSL. Different
backends (OpenGL/Metal/D3D) have different binding space rules. Common mistakes:
- Unused outputs in vertex shader not matched in fragment shader
- Duplicate bindslots across shader stages
- Missing `layout(binding=N)` annotations

**Consequences:**
- Compilation errors: "outputs of vs don't match inputs of fs"
- Runtime validation errors when binding uniforms
- Resources optimized out, causing slot mismatches

**Prevention:**
Follow sokol-shdc binding rules:
```glsl
// Uniform blocks need explicit binding (N >= 0 && N < 8)
layout(binding=0) uniform vs_params {
  mat4 transform;
};

// Bindings must be unique within type across stages
layout(binding=0) uniform texture2D tex;  // OK in VS
layout(binding=1) uniform texture2D tex;  // Different binding in FS

// Remove unused vertex shader outputs
// BAD: out vec4 color; // Declared but not used in FS
// GOOD: Only declare what FS actually consumes
```

Bindings must be unique within their type across all shader stages. Same resource name/type
must use same binding across programs.

**Detection:**
sokol-shdc compilation errors show binding mismatches. Runtime validation (if enabled) catches
optimized-out resources. Test on all target backends — OpenGL has different binding rules than
Metal.

**Implementation step:**
Shader authoring — apply binding annotations from first shader version.

**Confidence:** MEDIUM
**Sources:**
- [sokol-shdc documentation](https://github.com/floooh/sokol-tools/blob/master/docs/sokol-shdc.md)
- [Example shader code won't compile with shdc](https://github.com/floooh/sokol-tools/issues/113)

---

## Moderate Pitfalls

Mistakes that cause performance issues or technical debt.

### Pitfall 5: Procedural Gradient Computation Bottleneck

**What goes wrong:**
Frame rate tanks when many gradient-filled elements render. Fragment shader calculates gradient
colors procedurally for every pixel, overwhelming GPU with math operations.

**Why it happens:**
Procedural approach trades memory for computation. For simple gradients, per-pixel calculation
is 10-50+ shader instructions. Not leveraging GPU texture filtering hardware.

Trade-off:
- Textures: Fast (hardware filtering), high memory, bandwidth-limited
- Procedural: Slow (shader math), low memory, compute-limited

**Prevention:**

**Option A — Hybrid approach (best for v-gui):**
- Generate gradient texture once on CPU/GPU (1D for linear, 2D for radial)
- Use texture sampling in fragment shader (leverages hardware filtering)
- Cache textures for common gradients

**Option B — Optimize procedural:**
- Minimize per-pixel operations (precompute what you can)
- Use vertex shader for position calculations, interpolate in fragment
- Avoid loops in fragment shader (hard-code common stop counts or use uniform arrays)

For UI framework with frequent redraws: texture-based likely better. For infrequent gradients:
procedural acceptable.

**Detection:**
Profile with many gradient elements on screen. Watch for fragment shader bottleneck in GPU
profiler. If frame time dominated by fragment stage: optimization needed.

**Implementation step:**
Architecture decision — texture vs procedural affects initial implementation approach.

**Confidence:** MEDIUM
**Sources:**
- [Comparing performance of textures vs procedural shaders on mobile gpu](https://discussions.unity.com/t/comparing-performance-of-textures-vs-procedural-shaders-on-mobile-gpu/662156)
- [Procedural vs Image-Based Textures: A Comparison](https://www.linkedin.com/advice/1/what-advantages-disadvantages-using-procedural-textures)

---

### Pitfall 6: Vertex Color Interpolation Assumptions

**What goes wrong:**
Gradient appears with unexpected artifacts at element boundaries or doesn't interpolate
smoothly. Assuming default smooth interpolation but shader uses flat shading, or vice versa.

**Why it happens:**
GLSL defaults to smooth (Gouraud) shading — interpolates values between vertices. Can be
overridden with `flat` qualifier. If gradient implemented via vertex colors, interpolation
behavior matters.

For gradients:
- Linear: Typically want smooth interpolation from vertex colors
- Multi-stop: Vertex color interpolation insufficient (fragment shader needed)
- Flat shading: No interpolation, entire triangle gets single color

**Prevention:**
Be explicit about interpolation:
```glsl
// Vertex shader
smooth out vec4 vColor;  // Explicitly smooth interpolation (default)
flat out int vStopIndex; // Explicitly flat (no interpolation)

// Fragment shader
smooth in vec4 vColor;
flat in int vStopIndex;
```

For multi-stop gradients, vertex colors can't represent arbitrary stops. Need fragment shader
with uniform color array and position-based lookups.

**Detection:**
Visual inspection — hard edges where smooth expected, or smooth where hard expected. Particularly
visible at triangle boundaries in element geometry.

**Implementation step:**
Shader input/output definition — specify before implementing gradient logic.

**Confidence:** MEDIUM
**Sources:**
- [Flat and smooth shading](https://sites.nova.edu/mjl/graphics/lighting/flat-and-smooth-shading/)
- [Shading: Flat vs. Gouraud vs. Phong](https://www.baeldung.com/cs/shading-flat-vs-gouraud-vs-phong)

---

### Pitfall 7: Radial Gradient Overdraw Performance

**What goes wrong:**
Radial gradients slower than expected. Fragment shader calculates distance/angle per pixel,
even pixels outside gradient bounds.

**Why it happens:**
Radial gradients typically require distance calculations (sqrt for circular) or more complex
math (elliptical). Without bounds optimization, shader runs for entire element quad even if
gradient only covers small portion.

**Consequences:**
- Unnecessary fragment shader invocations
- Performance scales with screen-space area, not gradient coverage
- Particularly bad for large elements with small radial gradients

**Prevention:**

**Optimization 1 — Geometry clipping:**
Render only bounding box of gradient, not entire element quad. Reduces fragments processed.

**Optimization 2 — Early fragment discard:**
```glsl
float dist = distance(fragPos, gradientCenter);
if (dist > gradientRadius) {
  discard;  // Or: return backgroundColor;
}
```

**Optimization 3 — Avoid expensive operations:**
- For circular radials: distance() compiles to ~5 instructions including sqrt
- For elliptical: more complex — normalize to circle first
- Consider approximations for performance-critical cases

**Detection:**
GPU profiler shows high fragment shader cost. Frame time increases with radial gradient screen
coverage. Compare performance: linear (cheap) vs radial (expensive).

**Implementation step:**
Radial gradient implementation — include bounds optimization from start.

**Confidence:** MEDIUM
**Sources:**
- [Shader-based gradients performance discussion](https://github.com/Orama-Interactive/Pixelorama/pull/677)
- [Shaders - Overdraw.xyz](https://www.overdraw.xyz/blog/tag/Shaders)

---

## Minor Pitfalls

Mistakes that cause annoyance but are fixable.

### Pitfall 8: NaN from pow() Edge Cases

**What goes wrong:**
Gradient math produces NaN (not-a-number) for specific inputs, rendering pink/black instead of
expected color.

**Why it happens:**
`pow(x, y)` returns NaN when `x = 0.0` and `y <= 0.0`. If gradient interpolation or easing
functions use pow() with user-supplied parameters, edge cases can trigger NaN.

**Prevention:**
Guard pow() calls:
```glsl
// BAD:
color = pow(t, gamma);  // NaN if t=0 and gamma<=0

// GOOD:
color = pow(max(t, 0.0001), gamma);  // Clamp to small positive
```

Also watch for:
- Division by zero in normalization
- sqrt() of negative numbers
- log() of zero/negative

**Detection:**
Test with extreme gradient parameters: zero-length gradients, coincident color stops, gamma=0.
Look for pink (NaN indicator) or black pixels.

**Implementation step:**
Gradient math implementation — add guards when writing color interpolation code.

**Confidence:** HIGH
**Sources:**
- [Common Shader Mistakes](https://mini.gmshaders.com/p/mistakes)
- [GLSL: common mistakes - OpenGL Wiki](https://khronos.org/opengl/wiki/GLSL_:_common_mistakes)

---

### Pitfall 9: Unnecessary Vector Normalization

**What goes wrong:**
Fragment shader performance suboptimal. Normalizing vectors where not necessary, or normalizing
multiple times.

**Why it happens:**
Normalization (normalize()) involves sqrt and division — relatively expensive. Common mistake:
normalizing vectors that are already normalized, or normalizing when magnitude doesn't matter.

For gradients:
- Direction vectors for linear gradients: normalize once in vertex shader or CPU
- Interpolated normals: must renormalize in fragment shader (interpolation changes magnitude)
- Position-based calculations: often don't need normalization

**Prevention:**
```glsl
// BAD: Normalizing already-normalized uniform
uniform vec2 gradientDir;  // Assume already normalized
vec2 dir = normalize(gradientDir);  // Unnecessary

// GOOD:
vec2 dir = gradientDir;

// BAD: Normalizing when only direction matters in dot product
float t = dot(normalize(pos), normalize(dir));  // 2x normalize

// GOOD (if both already normalized):
float t = dot(pos, dir);
```

Normalize only when:
- Vector was interpolated (and needs to be unit length)
- Vector magnitude varies and you need unit vector
- After operations that change magnitude

**Detection:**
Shader instruction count analysis. Look for normalize() calls — question each one.

**Implementation step:**
Fragment shader optimization pass — after initial working implementation.

**Confidence:** MEDIUM
**Sources:**
- [Common Shader Mistakes](https://mini.gmshaders.com/p/mistakes)
- [OpenGL ES Programming Tips](https://docs.nvidia.com/drive/drive_os_5.1.6.1L/nvvib_docs/DRIVE_OS_Linux_SDK_Development_Guide/Graphics/graphics_opengl.html)

---

### Pitfall 10: Shader State Leakage Between Draws

**What goes wrong:**
Gradients render with wrong parameters occasionally. Uniform values from previous draw "leak"
into current draw.

**Why it happens:**
Setting texture parameters or uniform variables every draw even when unchanged wastes CPU time.
BUT not setting them when they DO change causes previous values to persist. Common in
immediate-mode rendering (sokol.sgl).

**Consequences:**
- Hard-to-reproduce rendering bugs (depends on draw order)
- Performance waste from redundant state changes
- Gradients with wrong colors/angles until state refreshed

**Prevention:**

**Option A — Always set all state (safe but slower):**
```v
// Set all gradient uniforms every draw
sgl.uniform_vec2('gradient_start', start)
sgl.uniform_vec2('gradient_end', end)
// ...etc
```

**Option B — Track state changes (fast but complex):**
```v
// Cache last-set values, only update when changed
if gradient.start != last_gradient.start {
  sgl.uniform_vec2('gradient_start', gradient.start)
}
```

For v-gui immediate mode: Option A safer. Optimize later if profiling shows uniform updates as
bottleneck.

**Detection:**
Gradients occasionally render with parameters from previous draw. Particularly visible when
switching between different gradients rapidly.

**Implementation step:**
Rendering integration — establish state management pattern early.

**Confidence:** MEDIUM
**Sources:**
- [Common Shader Mistakes](https://mini.gmshaders.com/p/mistakes)
- [OpenGL Common Mistakes](https://www.khronos.org/opengl/wiki/Common_Mistakes)

---

## Phase-Specific Warnings

Pitfalls mapped to likely implementation phases in v-gui gradient project.

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Shader infrastructure setup | Pitfall 2: Metal/GLSL coordinate mismatch | Configure sokol-shdc platform options from start |
| Shader infrastructure setup | Pitfall 3: Precision qualifiers missing | Declare precision explicitly in initial shader template |
| Linear gradient implementation | Pitfall 1: Color banding | Add dithering before first visual testing |
| Linear gradient implementation | Pitfall 8: NaN from pow() | Guard math operations in color interpolation |
| Multi-stop gradient implementation | Pitfall 4: sokol-shdc binding mismatches | Follow binding annotation rules for uniform arrays |
| Multi-stop gradient implementation | Pitfall 6: Vertex color interpolation assumptions | Use fragment shader with uniform color stops, not vertex colors |
| Radial gradient implementation | Pitfall 7: Radial gradient overdraw | Include early discard or bounds optimization |
| Performance optimization | Pitfall 5: Procedural gradient bottleneck | Decide texture vs procedural based on profiling |
| Performance optimization | Pitfall 9: Unnecessary normalization | Audit normalize() calls in optimization pass |
| Rendering integration | Pitfall 10: Shader state leakage | Set all gradient uniforms every draw (immediate mode) |

---

## Cross-Platform Testing Checklist

Before declaring gradients "done", verify on all platforms:

- [ ] macOS (Metal) — coordinate system correct, shaders compile
- [ ] Linux (OpenGL) — coordinate system correct, shaders compile
- [ ] Windows (OpenGL/D3D) — coordinate system correct, shaders compile
- [ ] Mobile/integrated GPU (if target) — precision qualifiers work, no compilation errors
- [ ] Low-contrast gradients — dithering prevents banding
- [ ] Extreme parameters — no NaN/inf artifacts (zero-length, gamma edge cases)
- [ ] Many gradients on screen — acceptable frame rate
- [ ] Rapid gradient changes — no state leakage bugs

---

## Additional Resources

**sokol-shdc specific:**
- [sokol-shdc documentation](https://github.com/floooh/sokol-tools/blob/master/docs/sokol-shdc.md)
- [A Tour of sokol_gfx.h](https://floooh.github.io/2017/07/29/sokol-gfx-tour.html)

**Shader cross-platform:**
- [Write HLSL for different graphics APIs - Unity](https://docs.unity3d.com/Manual/SL-PlatformDifferences.html)
- [Cross-Platform Shader Handling](https://stephanheigl.github.io/posts/shader-compiler/)

**Gradient implementation examples:**
- [Shaders Explained: Gradients - MTLDoc](https://mtldoc.com/metal/2022/08/04/shaders-explained-gradients)
- [A flowing WebGL gradient, deconstructed](https://alexharri.com/blog/webgl-gradients)

---

*Research confidence: MEDIUM-HIGH*

*Confidence rationale:*
- *HIGH confidence on well-documented issues (color banding, coordinate systems, precision)*
- *MEDIUM confidence on sokol-shdc specifics (less direct v-gui examples, generalized from docs)*
- *MEDIUM confidence on performance tradeoffs (context-dependent, need profiling to confirm)*

*Gaps:*
- *sokol-shdc with V language bindings — minimal examples found, may need experimentation*
- *v-gui specific performance characteristics — need profiling on actual codebase*
- *Mobile GPU testing — recommendations based on GLES standards, actual device testing needed*
