# GPU Gradient Rendering Stack

**Project:** v-gui multi-stop gradient support
**Researched:** 2026-02-01
**Confidence:** HIGH

## Executive Summary

**Recommendation:** Fragment shader approach with 1D texture lookup for multi-stop gradients.

Modern UI frameworks use two gradient strategies: fragment-shader-based (Warp, Skia) and
texture-atlas-based (WebRender). For v-gui's sokol/sgl context, fragment shaders are optimal
because:

1. v-gui already has custom shader pipelines (rounded rects, shadows, blur)
2. sokol/sgl doesn't provide texture atlas management primitives
3. Gradients in v-gui are geometry-bound (rectangles), not cached/reusable patterns
4. Fragment shader integrates cleanly with existing SDF shape rendering

## Recommended Approach: Fragment Shader + 1D Texture

### Core Technique

Render multi-stop gradients via fragment shader that samples a 1D gradient texture.

**Why 1D texture over procedural:**
- Multi-stop interpolation is complex in procedural code (branching, loops)
- GPU rasterizer handles interpolation for free when rendering 1D texture
- Matches Metal/GLSL best practices per MTLDoc

**Why fragment shader over texture atlas:**
- v-gui gradients are tied to specific geometry (per-rectangle)
- No caching opportunity (gradients defined inline, not reused)
- sokol/sgl has no built-in atlas management
- Texture atlas makes sense for shared patterns (WebRender), not inline gradients

### Implementation Strategy

**Phase 1: Generate 1D Gradient Texture**
- Create 1-pixel-height texture with width = interpolation resolution (e.g., 256 pixels)
- Use separate vertex shader to render gradient stops as vertices
- Let GPU rasterizer interpolate colors between stops
- Output to 1D texture (Metal: MTLTexture, GLSL: GL_TEXTURE_1D)

**Phase 2: Sample in Fragment Shader**
- Pass 1D texture to fragment shader as uniform
- Calculate sampling coordinate based on gradient type:
  - **Linear:** `t = dot(pixel_pos - start, direction) / length(direction)`
  - **Radial:** `t = length(pixel_pos - center) / radius`
- Sample texture: `color = texture(gradient_tex, t)`
- Apply to existing rounded rect SDF shader

**Phase 3: Integrate with Existing Pipeline**
- Extend `init_rounded_rect_pipeline` to add gradient variant
- Pack gradient type + texture binding in vertex attributes/uniforms
- Reuse existing SDF masking for rounded corners

## Technology Stack

### Core Technologies

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| sokol.gfx | Current (via V) | GPU abstraction | Already used, cross-platform |
| sokol.sgl | Current (via V) | Immediate-mode wrapper | Existing pipeline basis |
| Metal Shading Language | Metal 3+ | macOS shader code | Required for macOS target |
| GLSL | 330+ | Cross-platform shader | Required for non-macOS |

### New Capabilities Needed

| Capability | sokol.gfx API | Purpose |
|------------|---------------|---------|
| 1D texture creation | `gfx.make_image()` with `.type_1d` | Store gradient ramp |
| Texture binding | `gfx.ShaderImageDesc` | Pass gradient to shader |
| Off-screen render | `gfx.make_render_target()` | Generate gradient texture |

### Shader Architecture

**Gradient Generation Shader (1D texture creation):**
```metal
// Metal Vertex Shader
vertex GradientVertex vs_gradient(
    uint vid [[vertex_id]],
    constant GradientStop* stops [[buffer(0)]],
    constant uint& stop_count [[buffer(1)]]
) {
    GradientVertex out;
    out.position = float4(stops[vid].pos * 2.0 - 1.0, 0, 1);
    out.color = stops[vid].color;
    return out;
}

// Fragment shader: passthrough (rasterizer interpolates)
fragment float4 fs_gradient(GradientVertex in [[stage_in]]) {
    return in.color;
}
```

**Gradient Sampling Shader (rectangle rendering):**
```metal
// Extend existing fs_metal
fragment float4 fs_gradient_rect(VertexOut in [[stage_in]],
                                  texture1d<float> gradient_tex [[texture(1)]],
                                  sampler gradient_smp [[sampler(1)]]) {
    // Existing SDF logic for shape
    float2 half_size = 1.0 / (fwidth(in.uv) + 1e-6);
    float2 pos = in.uv * half_size;
    float2 q = abs(pos) - half_size + float2(radius);
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;

    // Gradient sampling
    float t;
    if (gradient_type == LINEAR) {
        // Unpack gradient direction from uniforms
        t = dot(in.uv, gradient_dir);
    } else { // RADIAL
        t = length(in.uv - gradient_center);
    }
    float4 gradient_color = gradient_tex.sample(gradient_smp, t);

    // Apply SDF mask
    float alpha = 1.0 - smoothstep(-0.59, 0.59, d / grad_len);
    return float4(gradient_color.rgb, gradient_color.a * alpha);
}
```

## Data Flow

```
1. CPU (V code):
   GradientStop[] -> gfx.Buffer

2. GPU Pass 1 (1D texture generation):
   Vertex Shader: stops -> clip space vertices
   Rasterizer: interpolate colors
   Fragment Shader: passthrough
   Output: 1D texture (256x1 RGBA)

3. GPU Pass 2 (rectangle rendering):
   Vertex Shader: rect geometry + gradient params
   Fragment Shader: sample 1D texture + SDF masking
   Output: final framebuffer
```

## Alternatives Considered

### Alternative 1: Procedural Fragment Shader (No Texture)

**Approach:** Calculate multi-stop interpolation directly in fragment shader.

```glsl
// Pseudocode
for (int i = 0; i < stop_count - 1; i++) {
    if (t >= stops[i].pos && t <= stops[i+1].pos) {
        float local_t = (t - stops[i].pos) / (stops[i+1].pos - stops[i].pos);
        return mix(stops[i].color, stops[i+1].color, local_t);
    }
}
```

**Why NOT:**
- Loops in fragment shaders are slow (no branch prediction)
- Uniform array limits (GL_MAX_FRAGMENT_UNIFORM_COMPONENTS ~1024, limits stops)
- Complex for radial gradients with many stops
- 1D texture approach delegates work to GPU rasterizer

### Alternative 2: Texture Atlas Pre-rendering (WebRender Style)

**Approach:** Pre-render gradients to texture atlas, sample as images.

**Why NOT:**
- v-gui gradients are defined inline per-rectangle, not reused
- No caching benefit (each gradient used once)
- sokol/sgl lacks atlas management (would need custom packer)
- Adds complexity: atlas packing, cache invalidation, eviction
- Only wins when gradients are shared across many instances

### Alternative 3: Vertex Color Interpolation (Current Hack)

**Approach:** Use per-vertex colors, rely on rasterizer interpolation.

**Current v-gui code:**
```v
fn draw_quad_gradient(x f32, y f32, w f32, h f32, z f32, c1 Color, c2 Color, ...) {
    sgl.begin_quads()
    sgl.c4b(c1.r, c1.g, c1.b, c1.a) // Top-left
    sgl.v3f(x, y, z)
    sgl.c4b(c2.r, c2.g, c2.b, c2.a) // Top-right
    sgl.v3f(x + w, y, z)
    // ...
}
```

**Why NOT:**
- Only supports 2 stops (4 vertices = 4 colors max)
- Linear interpolation only (radial impossible)
- Doesn't match CSS gradient spec (multi-stop, arbitrary positions)

## Cross-Platform Considerations

### Metal vs GLSL Differences

| Feature | Metal | GLSL | Handling |
|---------|-------|------|----------|
| 1D Texture Type | `texture1d<float>` | `sampler1D` | Separate shader source strings |
| Texture Binding | `[[texture(N)]]` | `uniform sampler1D` | Already handled by sokol |
| Sampler Config | Separate `[[sampler(N)]]` | Combined `sampler1D` | Use `gfx.ShaderImageSamplerPairDesc` |

**Sampler Configuration (both platforms):**
- Address mode: `clamp_to_edge` (pixels outside 0-1 use edge color)
- Filter: `linear` (smooth interpolation)

### sokol/sgl Integration

**Pipeline Setup (extend existing pattern):**
```v
fn init_gradient_pipeline(mut window Window) {
    // Similar to init_rounded_rect_pipeline but:
    // 1. Add texture slot for 1D gradient
    shader_images[1] = gfx.ShaderImageDesc{
        used: true
        image_type: ._1d  // KEY DIFFERENCE
        sample_type: .float
    }
    // 2. Add sampler for gradient
    shader_samplers[1] = gfx.ShaderSamplerDesc{
        used: true
        sampler_type: .filtering
    }
    // 3. Bind image-sampler pair
    shader_image_sampler_pairs[1] = gfx.ShaderImageSamplerPairDesc{
        used: true
        image_slot: 1
        sampler_slot: 1
        glsl_name: c'gradient_tex'
    }
}
```

**Gradient Texture Generation:**
```v
fn generate_gradient_texture(gradient &Gradient) gfx.Image {
    width := 256 // Resolution (higher = smoother, slower)

    // Create 1D texture
    mut img_desc := gfx.ImageDesc{
        type: ._1d
        width: width
        pixel_format: .rgba8
        usage: .immutable
        data: gfx.ImageData{
            // Filled by off-screen render pass
        }
    }

    // Off-screen render to generate texture
    // (Use gradient generation shader with stops as vertices)

    return gfx.make_image(&img_desc)
}
```

## Performance Characteristics

### Fragment Shader Approach

**Per-frame cost:**
- 1D texture generation: One-time per unique gradient (cacheable)
- Fragment shader: 1 texture sample + existing SDF math
- Overdraw: Same as current (quad covers rect bounds)

**Memory:**
- 1D texture: 256 pixels × 4 bytes (RGBA) = 1KB per gradient
- 100 unique gradients = 100KB (negligible)

**Batching:**
- Can batch multiple rects with same gradient (share texture binding)
- Different gradients require separate draw calls (texture rebind)

### Texture Atlas Approach (for comparison)

**Per-frame cost:**
- Atlas packing: CPU overhead for dynamic gradients
- Fragment shader: Similar (1 texture sample)
- Atlas updates: GPU upload if gradients change

**Memory:**
- Atlas: 2048x2048 RGBA = 16MB (typical WebRender size)
- Gradient eviction logic needed

**Batching:**
- Better batching (all gradients in one atlas = one texture bind)
- Only wins if many shared gradients

**Verdict:** Fragment shader + 1D texture wins for v-gui use case.

## Implementation Phases

### Phase 1: Linear Gradient (2 stops)

**Goal:** Replace current vertex-color hack with proper fragment shader.

**Changes:**
- Add gradient texture generation (2-stop → 1D texture)
- Add gradient sampling to fragment shader
- Support linear direction (horizontal, vertical, diagonal)
- Test on existing gradient examples

**Estimated effort:** ~1-2 days

### Phase 2: Multi-Stop Linear Gradient

**Goal:** Support arbitrary stop counts and positions.

**Changes:**
- Extend texture generation to N stops
- Add stop position handling (0.0-1.0 mapping)
- Match CSS gradient spec behavior

**Estimated effort:** ~1 day

### Phase 3: Radial Gradient

**Goal:** Support radial/circular gradients.

**Changes:**
- Add radial sampling logic (distance from center)
- Support center position + radius params
- Test with border-radius combinations

**Estimated effort:** ~1-2 days

### Phase 4: Border Gradients

**Goal:** Apply gradients to stroked rectangles.

**Changes:**
- Combine gradient sampling with stroke SDF
- Handle corner interpolation correctly

**Estimated effort:** ~1 day

## Pitfalls to Avoid

### 1. Texture Resolution Too Low

**Problem:** 256-pixel gradient shows banding on large rectangles.

**Solution:**
- Use 512 or 1024 for high-quality gradients
- Make resolution configurable per gradient
- Rely on GPU linear filtering to smooth

### 2. Uniform Array Limits

**Problem:** Passing stops as uniform array hits `GL_MAX_FRAGMENT_UNIFORM_COMPONENTS`.

**Solution:**
- Don't pass stops to fragment shader
- Pass stops to texture generation shader only
- Fragment shader samples pre-generated texture

### 3. sgl Texture Binding

**Problem:** sgl expects texture in slot 0, gradient in slot 1.

**Solution:**
- Use dummy texture in slot 0 (existing workaround)
- Bind gradient texture explicitly in slot 1
- Follow existing shadow pipeline pattern

### 4. Gradient Direction Rotation

**Problem:** CSS `linear-gradient(45deg, ...)` requires direction vector.

**Solution:**
- Store direction as normalized 2D vector in uniforms
- Use dot product for projection (Warp approach)
- Support angle → direction conversion on CPU

### 5. Color Interpolation Space

**Problem:** CSS gradients use premultiplied alpha.

**Solution:**
- Generate 1D texture in premultiplied space
- Match CSS spec: interpolate in premultiplied, output straight alpha
- Avoid gray artifacts when alpha changes

## Sources & References

**Modern UI Framework Approaches:**
- [MTLDoc: Shaders Explained - Gradients](https://mtldoc.com/metal/2022/08/04/shaders-explained-gradients)
- [Warp: How to Draw Styled Rectangles Using GPU and Metal](https://www.warp.dev/blog/how-to-draw-styled-rectangles-using-the-gpu-and-metal)
- [WebRender: Eight Million Pixels - GUIs on GPU](https://nical.github.io/drafts/gui-gpu-notes.html)
- [WebRender: Gradient GPU Cache Sharing](https://github.com/servo/webrender/pull/2454)
- [Skia: SkGradientShader Reference](https://api.skia.org/classSkGradientShader.html)

**Shader Implementation:**
- [MDN: CSS linear-gradient()](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/gradient/linear-gradient)
- [MDN: CSS radial-gradient()](https://developer.mozilla.org/en-US/docs/Web/CSS/gradient/radial-gradient)
- [GLSL Shader Tutorial: Basic Gradients](https://www.shader-learn.com/learn/basic/basic-gradients)
- [Khronos: Uniform Array Limitations](https://community.khronos.org/t/using-the-max-fragment-uniform-components-glsl-field-as-the-size-of-a-uniform-array/107609)

**sokol Ecosystem:**
- [sokol_gp: 2D Graphics Painter](https://github.com/edubart/sokol_gp)
- [sokol-gfx Compute Shader Update](https://floooh.github.io/2025/03/03/sokol-gfx-compute-update.html)

## Confidence Assessment

| Area | Confidence | Rationale |
|------|------------|-----------|
| Fragment shader approach | HIGH | Matches existing v-gui architecture, proven in Warp/Skia |
| 1D texture technique | HIGH | MTLDoc authoritative source, GPU rasterizer optimization |
| sokol/sgl integration | MEDIUM | sokol docs sparse, but existing shader pipeline proves feasible |
| Cross-platform parity | HIGH | Metal + GLSL already working for rounded rects/shadows |
| Performance | HIGH | Fragment shader cheaper than atlas for inline gradients |

**Overall:** HIGH confidence. Fragment shader + 1D texture is the right approach for v-gui's
context. Recommendation is specific, actionable, and proven by modern frameworks.
