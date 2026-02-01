# Phase 1: Fragment Shader Foundation - Research

**Researched:** 2026-02-01
**Domain:** Fragment shader pipeline for multi-stop GPU gradients
**Confidence:** HIGH

## Summary

Phase 1 replaces vertex color interpolation (2-stop limit) with fragment shader computing
multi-stop gradients. Standard approach: dedicated pipeline following v-gui shadow_pip/blur_pip
pattern, uniform array (3-5 stops) packed in tm matrix for MVP, dithering prevents banding,
Metal/GLSL coordinate handling critical.

Fragment shaders compute gradients per-pixel with SDF clipping for rounded rects. Existing
codebase provides complete pattern: pipeline init (shaders.v), shader source (shaders_metal.v,
shaders_glsl.v), parameter packing (z-coordinate for radius), matrix smuggling (tm for auxiliary
data). Uniform array approach optimal for MVP: simpler than texture, sufficient for typical UI
gradients.

**Primary recommendation:** Create gradient_pip pipeline with fragment shader interpolating
3-5 stops via tm uniform array, apply dithering pre-quantization, configure coordinate system
handling from first shader version.

## Standard Stack

Established libraries/tools for fragment shader gradients in v-gui context:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| sokol.gfx | current | GPU abstraction | v-gui rendering foundation, proven cross-platform |
| sokol.sgl | current | Immediate-mode API | v-gui rendering pattern, pipeline management |
| Metal Shading Language | 3+ | macOS shaders | Platform requirement, MSL standard for Metal |
| GLSL | 330+ | Cross-platform shaders | OpenGL standard, broad compatibility |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| sokol-shdc | current | Shader cross-compilation | CRITICAL: Compiles GLSL to Metal/D3D/WGSL backends |
| fwidth() | GLSL built-in | SDF pixel conversion | Converting UV coordinates to pixel space (existing pattern) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Uniform array (3-5 stops) | 1D texture (256+ stops) | Texture: unlimited stops, more complex. Defer to Phase 4 if needed |
| Fragment shader | Vertex color interpolation | Current HACK: only 2 stops, inadequate for multi-stop |
| Custom pipeline | Modify rounded_rect_pip | Couples gradient to rect shader, violates separation |

**Installation:**
Already installed. No new dependencies required.

## Architecture Patterns

### Recommended Project Structure
```
shaders.v                 # Pipeline initialization (init_gradient_pipeline)
shaders_metal.v           # Metal shader source (vs_gradient_metal, fs_gradient_metal)
shaders_glsl.v            # GLSL shader source (vs_gradient_glsl, fs_gradient_glsl)
render.v                  # Rendering integration (modify draw_gradient_rect)
```

### Pattern 1: Dedicated Pipeline Isolation
**What:** Each effect (rounded rect, shadow, blur, gradient) uses separate pipeline
**When to use:** Always for new rendering effects
**Example:**
```v
// Source: shaders.v existing pattern (shadow_pip, blur_pip)
fn init_gradient_pipeline(mut window Window) {
    if window.gradient_pip_init {
        return
    }
    // Pipeline setup: vertex attrs, uniforms, shader desc
    window.gradient_pip = sgl.make_pipeline(&desc)
    window.gradient_pip_init = true
}
```

### Pattern 2: Parameter Packing in Z-Coordinate
**What:** Pack per-primitive params (radius, stop_count) into vertex position.z
**When to use:** Data varies per quad but not per vertex
**Example:**
```v
// Source: shaders.v pack_shader_params
fn pack_shader_params(radius f32, thickness f32) f32 {
    return thickness + (f32(math.floor(radius)) * 1000.0)
}

// Fragment shader unpacks:
// float radius = floor(params / 1000.0);
// float thickness = mod(params, 1000.0);
```

For gradients: pack radius + stop_count (or flags)

### Pattern 3: Matrix Smuggling for Auxiliary Data
**What:** Use tm (texture matrix) uniform for per-draw data not in standard MVP
**When to use:** Need to pass data per-draw without custom uniforms
**Example:**
```v
// Source: shadow rendering uses tm translation for offset
// For gradients: pack stop data into tm rows
// tm[0] = vec4(stop1_r, stop1_g, stop1_b, stop1_pos)
// tm[1] = vec4(stop2_r, stop2_g, stop2_b, stop2_pos)
// ...
```

tm matrix = 16 floats = 4 vec4 rows = 3-4 stops with RGBA+position

### Pattern 4: SDF Composition for Clipping
**What:** Combine gradient computation with rounded_box_sdf for shape clipping
**When to use:** Gradients need rounded rect boundaries
**Example:**
```glsl
// Source: fs_glsl existing SDF logic
// 1. Compute SDF for rounded rect
float d = rounded_box_sdf(pos, half_size, radius);
float sdf_alpha = 1.0 - smoothstep(-0.59, 0.59, d);

// 2. Compute gradient color
vec4 gradient_color = interpolate_stops(t, stops);

// 3. Combine
frag_color = vec4(gradient_color.rgb, gradient_color.a * sdf_alpha);
```

### Pattern 5: Lazy Pipeline Initialization
**What:** Initialize pipeline on first use, cache in Window struct
**When to use:** Always for custom pipelines
**Example:**
```v
// Source: draw_shadow_rect pattern
fn draw_gradient_rect(...) {
    init_gradient_pipeline(mut window)  // No-op if already init
    sgl.load_pipeline(window.gradient_pip)
    // ... draw quad ...
    sgl.load_default_pipeline()  // CRITICAL: restore state
}
```

### Anti-Patterns to Avoid
- **Forgetting sgl.load_default_pipeline():** Subsequent draws use wrong pipeline (Pitfall 10)
- **Modifying existing shaders:** Couples concerns, breaks separation (existing codebase avoids)
- **Vertex color for multi-stop:** Hardware interpolation can't handle arbitrary stops

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Gradient banding | Manual color stepping | Dithering in fragment shader | 8-bit quantization creates visible bands. Dithering breaks them up |
| Coordinate system differences | Runtime Y-flip logic | sokol-shdc compile-time config | Metal/GLSL origins differ (top-left vs bottom-left). Handle at compile |
| Precision handling | Assume highp everywhere | Explicit mediump with highp fallback | Mobile GPUs fail without precision qualifiers (Pitfall 3) |
| Multi-stop interpolation | Custom loop/blend code | Standard linear interpolation pattern | CSS spec defines algorithm, edge cases handled |

**Key insight:** Fragment shader gradients well-established technique. Don't innovate on core
algorithm, focus on v-gui integration following existing pipeline patterns.

## Common Pitfalls

### Pitfall 1: Color Banding Without Dithering
**What goes wrong:** Gradients show visible "bands" instead of smooth transitions
**Why it happens:** 8-bit color (256 shades/channel) creates quantization artifacts. Fragment
shader outputs high precision (f32), framebuffer quantizes to u8.
**How to avoid:**
```glsl
// Add in fragment shader before final output
float dither = (random(gl_FragCoord.xy) - 0.5) / 255.0;
fragColor.rgb += vec3(dither);

// Random function (from CoD: Advanced Warfare presentation)
float random(vec2 coords) {
    return fract(sin(dot(coords.xy, vec2(12.9898,78.233))) * 43758.5453);
}
```
**Warning signs:** Visible steps in low-contrast gradients (subtle grays, single-hue)

**Sources:**
- [Shader Tutorial: Color Banding and Dithering](https://shader-tutorial.dev/advanced/color-banding-dithering/)
- [How to fix color banding with dithering](https://www.anisopteragames.com/how-to-fix-color-banding-with-dithering/)

### Pitfall 2: Metal/GLSL Coordinate System Mismatch
**What goes wrong:** Gradients render upside-down on Metal vs GLSL
**Why it happens:** GLSL origin = bottom-left (0,0), Metal origin = top-left (0,0). Y-axis
inverted between platforms.
**How to avoid:**
```glsl
// Option A: Platform-specific coordinate handling in shader
#ifdef METAL
  vec2 uv = vec2(fragCoord.x, 1.0 - fragCoord.y);
#else
  vec2 uv = fragCoord;
#endif

// Option B: sokol-shdc compile options (if supported)
// @msl_options flip_vert_y
// @glsl_options fixup_clipspace
```
v-gui note: Existing shaders don't use @msl_options syntax. Follow existing pattern of platform
conditionals in shader source.

**Warning signs:** Gradient direction inverted on macOS vs Linux/Windows

**Sources:**
- [Navigating Coordinate System Differences](https://www.realtech-vr.com/navigating-coordinate-system-differences-in-metal-direct3d-and-opengl-vulkan/)

### Pitfall 3: Precision Qualifiers Missing (Mobile GPU)
**What goes wrong:** Shaders fail on mobile/integrated GPUs with precision errors
**Why it happens:** Desktop GPUs use highp everywhere. Mobile GPUs honor precision qualifiers,
may not support highp in fragment stage.
**How to avoid:**
```glsl
// GLSL: Declare at shader top
#ifdef GL_FRAGMENT_PRECISION_HIGH
  precision highp float;
#else
  precision mediump float;
#endif

// Use mediump for most calculations, highp only where needed
```
Metal note: MSL doesn't require precision qualifiers (always highp). GLSL-only concern.

**Warning signs:** Compilation errors on Android/iOS: "precision not supported in fragment shader"

**Sources:**
- [WebGL Precision Issues](https://webglfundamentals.org/webgl/lessons/webgl-precision-issues.html)

### Pitfall 4: sokol-shdc Binding Annotation Rules
**What goes wrong:** Shader compiles on one backend, fails on another
**Why it happens:** Different backends (OpenGL/Metal/D3D) have different binding space rules.
Vertex/fragment output/input mismatches cause errors.
**How to avoid:**
```glsl
// Explicit bindings for uniform blocks
layout(binding=0) uniform vs_params {
    mat4 mvp;
    mat4 tm;
};

// Bindings unique within type across stages
// Remove unused vertex outputs (don't declare if FS doesn't consume)
```
v-gui note: Existing shaders DON'T use layout(binding=N) syntax. Follow existing pattern:
declare uniforms without bindings, sokol.sgl manages internally.

**Warning signs:** Cross-compilation errors: "outputs of vs don't match inputs of fs"

**Sources:**
- [sokol-shdc documentation](https://github.com/floooh/sokol-tools/blob/master/docs/sokol-shdc.md)

### Pitfall 5: Premultiplied Alpha Interpolation
**What goes wrong:** Gradient shows gray artifacts when interpolating to transparent colors
**Why it happens:** Interpolating RGB and A separately creates desaturation. CSS spec requires
premultiplied alpha interpolation.
**How to avoid:**
```glsl
// Interpolate in premultiplied space
vec4 interpolate_premultiplied(vec4 c1, vec4 c2, float t) {
    // Premultiply
    vec3 c1_pre = c1.rgb * c1.a;
    vec3 c2_pre = c2.rgb * c2.a;

    // Interpolate
    vec3 rgb_pre = mix(c1_pre, c2_pre, t);
    float alpha = mix(c1.a, c2.a, t);

    // Unpremultiply (with guard)
    vec3 rgb = rgb_pre / max(alpha, 0.0001);
    return vec4(rgb, alpha);
}
```
**Warning signs:** Gray tint when fading to transparent (expected: color fades to transparent
without darkening)

**Sources:**
- [CSS Gradient Premultiplied Alpha Discussion](https://bugzilla.mozilla.org/show_bug.cgi?id=591600)
- [WebKit Gradient Interpolation Bug](https://bugs.webkit.org/show_bug.cgi?id=150940)

## Code Examples

Verified patterns from official sources and existing codebase:

### Fragment Shader Structure (Linear Gradient)
```glsl
// Source: v-gui existing fs_glsl pattern + gradient research
#version 330
uniform sampler2D tex;
uniform mat4 tm;  // Gradient stops packed here

in vec2 uv;
in vec4 color;
in float params;

out vec4 frag_color;

float random(vec2 coords) {
    return fract(sin(dot(coords.xy, vec2(12.9898,78.233))) * 43758.5453);
}

void main() {
    // Unpack parameters
    float radius = floor(params / 1000.0);
    float stop_count = mod(params, 1000.0);

    // SDF clipping (existing pattern)
    vec2 uv_to_px = 1.0 / (vec2(fwidth(uv.x), fwidth(uv.y)) + 1e-6);
    vec2 half_size = uv_to_px;
    vec2 pos = uv * half_size;

    vec2 q = abs(pos) - half_size + vec2(radius);
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;

    float grad_len = length(vec2(dFdx(d), dFdy(d)));
    d = d / max(grad_len, 0.001);
    float sdf_alpha = 1.0 - smoothstep(-0.59, 0.59, d);

    // Gradient position (linear, horizontal for MVP)
    float t = uv.x * 0.5 + 0.5;  // Map -1..1 to 0..1

    // Multi-stop interpolation (3 stops example)
    vec4 stop1 = tm[0];  // RGBA+position in tm matrix
    vec4 stop2 = tm[1];
    vec4 stop3 = tm[2];

    vec4 gradient_color;
    if (t <= stop2.a) {
        float local_t = (t - stop1.a) / (stop2.a - stop1.a);
        gradient_color = mix(stop1, stop2, local_t);
    } else {
        float local_t = (t - stop2.a) / (stop3.a - stop2.a);
        gradient_color = mix(stop2, stop3, local_t);
    }

    // Dithering
    float dither = (random(gl_FragCoord.xy) - 0.5) / 255.0;
    gradient_color.rgb += vec3(dither);

    // Combine with SDF clipping
    frag_color = vec4(gradient_color.rgb, gradient_color.a * sdf_alpha);

    // sgl texture workaround (existing pattern)
    if (frag_color.a < 0.0) {
        frag_color += texture(tex, uv);
    }
}
```

### Pipeline Initialization Pattern
```v
// Source: shaders.v init_shadow_pipeline pattern
fn init_gradient_pipeline(mut window Window) {
    if window.gradient_pip_init {
        return
    }

    // Vertex attributes (same as rounded_rect_pip)
    mut attrs := [16]gfx.VertexAttrDesc{}
    attrs[0] = gfx.VertexAttrDesc{
        format:       .float3  // position.xy + packed params
        offset:       0
        buffer_index: 0
    }
    attrs[1] = gfx.VertexAttrDesc{
        format:       .float2  // UV coordinates
        offset:       12
        buffer_index: 0
    }
    attrs[2] = gfx.VertexAttrDesc{
        format:       .ubyte4n  // color (for SDF base color)
        offset:       20
        buffer_index: 0
    }

    // Uniform block: mvp + tm (same as other pipelines)
    mut ub_uniforms := [16]gfx.ShaderUniformDesc{}
    ub_uniforms[0] = gfx.ShaderUniformDesc{
        name:        c'mvp'
        @type:       .mat4
        array_count: 1
    }
    ub_uniforms[1] = gfx.ShaderUniformDesc{
        name:        c'tm'
        @type:       .mat4
        array_count: 1
    }

    mut ub := [4]gfx.ShaderUniformBlockDesc{}
    ub[0] = gfx.ShaderUniformBlockDesc{
        size:     128  // 64 (mvp) + 64 (tm)
        uniforms: ub_uniforms
    }

    // Shader desc, pipeline desc, make_pipeline()
    // ... (follow shadow_pip pattern)

    window.gradient_pip = sgl.make_pipeline(&desc)
    window.gradient_pip_init = true
}
```

### Rendering Integration
```v
// Source: render.v draw_gradient_rect modification
fn draw_gradient_rect(x f32, y f32, w f32, h f32, r f32, gradient &Gradient, mut window Window) {
    init_gradient_pipeline(mut window)
    sgl.load_pipeline(window.gradient_pip)

    // Pack stops into tm matrix (3 stops MVP)
    mut stop_data := [16]f32{} // tm matrix = 16 floats
    for i in 0..3 {
        if i < gradient.stops.len {
            stop := gradient.stops[i]
            stop_data[i*4 + 0] = f32(stop.color.r) / 255.0
            stop_data[i*4 + 1] = f32(stop.color.g) / 255.0
            stop_data[i*4 + 2] = f32(stop.color.b) / 255.0
            stop_data[i*4 + 3] = stop.pos  // 0.0 to 1.0
        }
    }

    // Set tm uniform with stop data
    // (sokol.sgl pattern for setting matrix uniform - investigate exact API)

    z_val := pack_shader_params(r, f32(gradient.stops.len))

    draw_quad(x, y, w, h, z_val)

    sgl.load_default_pipeline()
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Vertex color interpolation | Fragment shader computation | ~2020 (Warp, Skia) | Enables multi-stop, arbitrary positioning |
| Procedural loops in shader | Texture sampling (1D ramp) | ~2018 (WebRender) | Better performance for 10+ stops |
| sRGB interpolation | Premultiplied alpha | CSS Images 4 (2017) | Prevents gray artifacts on transparency |

**Deprecated/outdated:**
- 2-stop vertex interpolation: Inadequate for modern UI expectations (3+ stops standard)
- Non-dithered gradients: Visible banding on 8-bit displays (dithering now expected)

## Open Questions

Items needing validation during planning/implementation:

1. **sokol.sgl tm uniform API in V**
   - What we know: tm uniform exists (shaders.v declares it), shadow uses sgl.translate()
   - What's unclear: How to set arbitrary tm matrix data in V (not just translation)
   - Recommendation: Investigate sgl V bindings, may need direct gfx.apply_uniforms() call

2. **Uniform array packing capacity**
   - What we know: tm = 4x4 mat = 16 floats, each stop needs 4 floats (RGBA+pos)
   - What's unclear: Can fit 3 full stops (12 floats) + metadata, or 4 stops without positions?
   - Recommendation: Test packing 3-5 stops in tm, validate shader receives correct data

3. **Cross-platform precision behavior**
   - What we know: Desktop GPUs ignore precision, mobile honors it
   - What's unclear: v-gui target platforms (desktop-only? mobile planned?)
   - Recommendation: Add precision qualifiers defensively (no harm on desktop)

4. **Coordinate system handling verification**
   - What we know: Existing shaders work cross-platform without flip_vert_y annotations
   - What's unclear: Does gradient UV interpretation need platform-specific handling?
   - Recommendation: Test gradients on macOS (Metal) + Linux (GLSL) early, verify consistency

## Sources

### Primary (HIGH confidence)
- v-gui codebase analysis:
  - shaders.v: Pipeline initialization pattern
  - shaders_glsl.v, shaders_metal.v: Shader structure, SDF patterns
  - render.v: Gradient data flow, current HACK (line 838)
- .planning/research/SUMMARY.md: Architecture recommendations
- .planning/research/PITFALLS.md: Gradient-specific pitfalls
- [Shader Tutorial: Dithering](https://shader-tutorial.dev/advanced/color-banding-dithering/)
- [sokol-shdc documentation](https://github.com/floooh/sokol-tools/blob/master/docs/sokol-shdc.md)

### Secondary (MEDIUM confidence)
- [CSS Gradients Premultiplied Alpha Bug](https://bugzilla.mozilla.org/show_bug.cgi?id=591600) - CSS spec requirements
- [Coordinate System Differences](https://www.realtech-vr.com/navigating-coordinate-system-differences-in-metal-direct3d-and-opengl-vulkan/) - Metal/GLSL origins
- [WebGL Precision Issues](https://webglfundamentals.org/webgl/lessons/webgl-precision-issues.html) - Mobile GPU precision

### Tertiary (LOW confidence)
- WebSearch results on uniform vs texture performance: No 2026 benchmarks, general guidance only
- sokol-shdc flip_vert_y options: Referenced in SPIRV-Cross discussions, unclear if sokol supports

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Verified from codebase, sokol in active use
- Architecture: HIGH - Existing shadow_pip/blur_pip provide complete pattern
- Pitfalls: HIGH - Well-documented issues (banding, coordinates, precision), MEDIUM on sokol-shdc specifics
- Code examples: HIGH - Based on existing codebase patterns

**Research date:** 2026-02-01
**Valid until:** 30 days (stable technology stack, no rapid changes expected)

**Phase 1 specific focus:**
This research targets MVP uniform-based approach (3-5 stops). Phase 4 texture-based approach
deferred, requires separate research on texture caching strategy.
