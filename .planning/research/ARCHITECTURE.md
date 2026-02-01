# Gradient Rendering Integration Architecture

**Project:** v-gui gradient rendering
**Researched:** 2026-02-01
**Confidence:** HIGH

## Executive Summary

v-gui uses sokol.sgl immediate-mode rendering with custom SDF shaders. Current gradient
implementation is vertex-interpolation-based (HACK comment at render.v:838) supporting only 2
stops. Full gradient support requires dedicated fragment shader pipeline following established
patterns for shadow/blur rendering.

**Recommendation:** Create dedicated gradient pipeline with fragment shader computing multi-stop
gradients procedurally. Reuse existing pipeline infrastructure (packing params in z-coordinate,
SDF clipping for rounded rects).

## Current Architecture Analysis

### Rendering Pipeline Structure

v-gui rendering follows 3-stage pipeline:

```
View Generation → Layout Calculation → Render
     ↓                    ↓                ↓
   View tree     Layout tree (shapes)   Renderer array
```

**Stage 1: View → Layout**
- Views generate Shape structs with gradient references
- Gradient stored in Shape.gradient field (pointer to Gradient)
- Shape contains: position, size, radius, gradient reference

**Stage 2: Layout → Renderer**
- render_shape() converts Shape to Renderer union types
- For gradients: creates DrawGradient{x, y, w, h, radius, gradient}
- Renderer array built in window.renderers[]

**Stage 3: Renderer → GPU**
- renderers_draw() walks renderer array
- renderer_draw() matches on DrawGradient
- Calls draw_gradient_rect() passing gradient data to GPU

### Existing Pipeline Architecture

v-gui uses 3 custom sokol.sgl pipelines:

| Pipeline | Purpose | Shader | Param Packing |
|----------|---------|--------|---------------|
| rounded_rect_pip | Filled/stroked rects | SDF rounded box | radius, thickness |
| shadow_pip | Drop shadows | SDF + Gaussian blur | radius, blur + offset via tm |
| blur_pip | Blur effects | SDF + blur | radius, blur |

**Key Pattern:** All pipelines pack parameters into vertex z-coordinate:
```v
z_val = thickness + (floor(radius) * 1000.0)
```

Fragment shader unpacks:
```glsl
float radius = floor(params / 1000.0);
float thickness = mod(params, 1000.0);
```

**Vertex attributes (shared across pipelines):**
- position (vec3): x, y, packed_params
- texcoord0 (vec2): UV in range [-1.0, 1.0] for SDF calculation
- color0 (vec4): RGBA color (interpolated per-vertex)

### Current Gradient Implementation (Limitations)

Location: render.v:810-887

**Implementation:**
1. Uses existing rounded_rect_pip (no dedicated shader)
2. Assigns vertex colors: c1 to corners based on gradient type
3. Hardware interpolates between vertex colors
4. Supports only first and last stop

**Limitations (per HACK comment line 838):**
- Only 2 stops supported (first, last)
- Intermediate stops ignored
- No control over stop positions (always 0.0, 1.0)
- No angle control for linear gradients (always horizontal/corner-based)
- Radial gradient center fixed

**Current data flow:**
```
Gradient struct → extract stops[0], stops[last] → assign to quad corners → vertex interpolation
```

## Proposed Architecture

### Option 1: Dedicated Gradient Pipeline (RECOMMENDED)

**Why:** Matches existing pattern (shadow_pip, blur_pip), maximum control, supports all features.

#### Integration Points

**1. Pipeline Initialization**
Location: shaders.v (new function)

```v
fn init_gradient_pipeline(mut window Window) {
    // Pattern: Same structure as init_shadow_pipeline
    // Creates window.gradient_pip and window.gradient_pip_init
}
```

**2. Shader Creation**
Locations: shaders_glsl.v, shaders_metal.v (new shaders)

Fragment shader receives:
- UV coordinates (-1.0 to 1.0)
- Packed params in z (radius, stop_count or flags)
- Base color (for SDF clipping)

Fragment shader computes:
- SDF for rounded rect (clipping)
- Gradient position based on UV and gradient type
- Color interpolation across stops
- Final pixel color = gradient_color * sdf_alpha

**3. Gradient Data Transmission**

**Challenge:** Fragment shader needs access to gradient stops array. Sokol.sgl immediate-mode
doesn't support per-draw uniform arrays easily.

**Solution A: Texture-Based (RECOMMENDED for >3 stops)**
- Create 1D texture storing gradient stops
- Each texel = RGBA stop (R,G,B,A = color, position stored separately or in alpha)
- Fragment shader samples texture based on computed gradient position
- Max stops: texture width (typically 256+)

**Solution B: Uniform Array (3-5 stops)**
- Pass stops as uniform array via texture matrix hack (current shadow offset pattern)
- Limited by uniform size (tm matrix = 16 floats = 4 vec4s = ~3 stops with positions)

**Solution C: Vertex Attributes (2-3 stops only)**
- Pack stop data into additional vertex attributes
- Requires modifying pipeline vertex layout

**Decision Matrix:**

| Approach | Max Stops | Performance | Complexity | Recommended For |
|----------|-----------|-------------|------------|------------------|
| Texture | 256+ | High (1 texture fetch) | Medium | Production |
| Uniform | 3-5 | Highest (no texture) | Low | MVP/simple gradients |
| Vertex | 2-3 | High | Low | Current limitation okay |

**Recommendation:** Start with Uniform Array (Solution B) for MVP, migrate to Texture (Solution A)
for production. Mirrors existing architecture where shadow_pip uses tm for offset.

**4. Rendering Function**
Location: render.v (new function)

```v
fn draw_gradient_rect_full(x, y, w, h, radius, gradient, mut window) {
    init_gradient_pipeline(mut window)
    sgl.load_pipeline(window.gradient_pip)

    // Pack gradient metadata into z-coordinate
    // Pack stop data into texture matrix or texture

    draw_quad(x, y, w, h, z_val)
    sgl.load_default_pipeline()
}
```

### Option 2: Enhanced Existing Pipeline

**Why:** Minimal changes, but limited.

Modify fs_glsl/fs_metal in existing rounded_rect shaders to compute gradients. Requires passing
gradient data via uniforms (limited to ~3 stops).

**Trade-off:** Couples gradient logic to rounded rect shader, harder to extend.

**Not recommended:** Violates separation of concerns, existing shaders already complex.

### Option 3: Multi-Pass with Stencil

**Why:** Use stencil buffer to mask gradient quad to rounded rect shape.

**Approach:**
1. Pass 1: Draw rounded rect to stencil buffer
2. Pass 2: Draw gradient quad with stencil test

**Trade-off:** Requires stencil buffer, more draw calls, potential batching issues.

**Not recommended:** Overengineered for immediate-mode API, breaks single-pass pattern.

## Data Flow: Gradient struct → GPU

### Current Data Path (Vertex Interpolation)

```
styles.v: Gradient struct
    ↓
render.v: render_container() detects shape.gradient
    ↓
render.v: DrawGradient renderer created
    ↓
render.v: renderer_draw() matches DrawGradient
    ↓
render.v: draw_gradient_rect() extracts stops[0], stops[last]
    ↓
render.v: draw_quad_gradient() assigns colors to vertices
    ↓
GPU: vertex shader passes color0 to fragment shader
    ↓
GPU: fragment shader interpolates (hardware)
    ↓
Pixels rendered
```

### Proposed Data Path (Fragment Shader)

```
styles.v: Gradient struct (stops[], type, start/end coords)
    ↓
render.v: render_container() detects shape.gradient
    ↓
render.v: DrawGradient renderer created (unchanged)
    ↓
render.v: renderer_draw() matches DrawGradient
    ↓
render.v: draw_gradient_rect_full() NEW FUNCTION
    ↓
    ├─→ Upload gradient stops to texture OR
    └─→ Pack stops into uniform (tm matrix)
    ↓
shaders.v: init_gradient_pipeline() (if not initialized)
    ↓
GPU: vertex shader passes UV, packed params
    ↓
GPU: fragment shader:
    - Compute SDF for rounded rect clipping
    - Compute gradient position from UV
    - Sample/interpolate gradient color from stops
    - Output: gradient_color * sdf_alpha
    ↓
Pixels rendered
```

### Fragment Shader Pseudo-Logic

```glsl
// Unpack parameters
float radius = floor(params / 1000.0);
float stop_count = mod(params, 1000.0);

// SDF clipping (reuse rounded rect logic)
vec2 half_size = 1.0 / (fwidth(uv) + 1e-6);
vec2 pos = uv * half_size;
float sdf = rounded_box_sdf(pos, half_size, radius);
float alpha = smoothstep(0.59, -0.59, sdf);

// Gradient position calculation
float t; // position along gradient (0.0 to 1.0)
if (gradient_type == LINEAR) {
    // Linear: project UV onto gradient vector
    vec2 grad_dir = normalize(end_pos - start_pos);
    t = dot(uv, grad_dir) * 0.5 + 0.5; // map -1..1 to 0..1
} else {
    // Radial: distance from center
    vec2 center = (start_pos + end_pos) * 0.5;
    t = length(uv - center) / max_radius;
}

// Multi-stop interpolation
vec4 gradient_color = interpolate_stops(t, stops, stop_count);

// Final output
frag_color = vec4(gradient_color.rgb, gradient_color.a * alpha);
```

## Suggested Implementation Order

### Phase 1: Uniform-Based MVP (3-5 stops)
**Goal:** Replace vertex interpolation with fragment shader, support multi-stop.

1. Create gradient pipeline initialization (shaders.v)
2. Write fragment shaders (shaders_glsl.v, shaders_metal.v)
   - Support 3-5 stops via tm uniform
   - Linear gradients only
   - Reuse SDF rounded rect clipping
3. Modify draw_gradient_rect() to use new pipeline
4. Test with 2, 3, 4, 5 stop gradients

**Validation:** Compare rendering against vertex-interpolation baseline (2 stops).

### Phase 2: Gradient Direction Control
**Goal:** Support arbitrary linear gradient angles.

1. Use gradient.start_x/y, end_x/y fields (already in struct)
2. Pass direction vector via tm uniform (pack into unused slots)
3. Fragment shader computes projection onto gradient axis
4. Test horizontal, vertical, diagonal gradients

### Phase 3: Radial Gradient Support
**Goal:** Implement radial gradient type.

1. Fragment shader branch on gradient type (packed in z)
2. Compute distance from center for radial
3. Test radial gradients with different centers/radii

### Phase 4: Texture-Based Stops (Production)
**Goal:** Support unlimited stops efficiently.

1. Create 1D texture from gradient stops
2. Upload texture per unique gradient (cache by gradient ID)
3. Fragment shader samples texture instead of uniform array
4. Benchmark performance vs uniform approach

**Trade-off:** Texture upload overhead vs unlimited stops. Profile before implementing.

### Phase 5: Gradient Border Support
**Goal:** Support gradient on borders (border_gradient field).

1. Modify draw_gradient_border() to use gradient pipeline
2. Fragment shader uses stroke SDF logic (abs(d + thickness*0.5) - thickness*0.5)
3. Apply gradient color to stroke region only

## Architecture Patterns to Follow

### Pattern 1: Pipeline Isolation
Each effect (rounded rect, shadow, blur, gradient) has dedicated pipeline. Don't overload shaders.

**Example:** shadow_pip separate from blur_pip despite similar SDF logic.

### Pattern 2: Parameter Packing
Use z-coordinate for per-primitive parameters. Keeps vertex layout simple.

**Example:** pack_shader_params(radius, thickness) packs 2 values into 1 float.

**For gradients:** Pack radius + stop_count (or flags for type/features).

### Pattern 3: Matrix Smuggling
Use tm (texture matrix) uniform for auxiliary per-draw data.

**Example:** shadow_pip passes offset via tm translation component.

**For gradients:** Pack gradient direction vector or stop data into tm.

### Pattern 4: SDF Composition
Combine multiple SDFs for complex shapes.

**Example:** shadow_pip combines rounded_box_sdf with casting_box_sdf.

**For gradients:** Combine gradient_sdf with rounded_box_sdf for clipping.

### Pattern 5: Lazy Initialization
Initialize pipelines on first use, cache in window.

**Example:** init_shadow_pipeline() checks window.shadow_pip_init flag.

**For gradients:** init_gradient_pipeline() follows same pattern.

## Performance Considerations

### Batching
Gradients may break batching if each draw requires different texture/uniforms.

**Mitigation:**
- Group shapes by gradient (sort renderer array)
- Use texture atlas for stops (pack multiple gradients into single texture)
- Limit texture rebinds

### Shader Complexity
Multi-stop interpolation adds fragment shader cost.

**Benchmarks (from web research):**
- 2-3 stops: negligible overhead
- 5-10 stops: ~5-10% fragment shader cost
- 15+ stops: texture lookup preferred over loop

**Decision:** Start with 3-5 stops (uniform), measure performance, texture if needed.

### Memory
Each gradient needs stops data on GPU.

**Options:**
- Uniform: ~48 bytes per gradient (3 stops × 16 bytes)
- Texture: ~1KB per gradient (256 texels × 4 bytes)

**Recommendation:** Uniform for MVP, acceptable overhead for typical UI (10-50 gradients/frame).

## Build Order Implications

### Dependencies
Gradient rendering depends on:
- Existing pipeline infrastructure (shaders.v)
- SDF rounded rect logic (fs_glsl, fs_metal)
- Gradient struct (styles.v) — already exists
- DrawGradient renderer (render.v) — already exists

**No blocking dependencies.** Can implement independently.

### Testing Strategy
1. Unit test: shader logic (SDF + gradient computation)
2. Visual test: compare 2-stop gradient (new vs old)
3. Visual test: multi-stop gradients (3, 5 stops)
4. Performance test: render 100 gradients, measure frame time
5. Integration test: gradient in containers, buttons (styles)

### Migration Path
1. Keep existing draw_gradient_rect() as fallback
2. Implement draw_gradient_rect_full() alongside
3. Feature flag: window.use_shader_gradients (default: true)
4. Test in production, rollback if issues
5. Remove old implementation after validation

## Known Pitfalls

### Pitfall 1: Color Space
**Issue:** Gradients often rendered in linear space but UI expects sRGB.

**Prevention:** Fragment shader applies gamma correction if needed:
```glsl
gradient_color = pow(gradient_color, vec4(1.0/2.2));
```

**Detection:** Gradients appear darker/washed out compared to solid colors.

### Pitfall 2: Stop Ordering
**Issue:** Stops not sorted by position → incorrect interpolation.

**Prevention:** Sort stops by pos in Gradient constructor or render path.

**Detection:** Gradient colors appear inverted or jumbled.

### Pitfall 3: Uniform Size Limits
**Issue:** tm matrix limited to 16 floats → max 3 stops with positions.

**Prevention:** Document stop limit, add runtime check.

**Detection:** Crash or garbage rendering with >3 stops.

### Pitfall 4: Texture Coordinate Precision
**Issue:** fwidth() unreliable at very small sizes → SDF clipping artifacts.

**Prevention:** Add epsilon to fwidth() (already done in existing shaders: + 1e-6).

**Detection:** Jagged edges on small rounded gradients.

### Pitfall 5: Pipeline State Leaks
**Issue:** Forgetting sgl.load_default_pipeline() → subsequent draws use gradient pipeline.

**Prevention:** Always pair load_pipeline() with load_default_pipeline().

**Detection:** Non-gradient shapes render incorrectly.

## Integration Checklist

- [ ] Create init_gradient_pipeline() in shaders.v
- [ ] Add gradient_pip, gradient_pip_init to Window struct
- [ ] Write vs_gradient_glsl/fs_gradient_glsl in shaders_glsl.v
- [ ] Write vs_gradient_metal/fs_gradient_metal in shaders_metal.v
- [ ] Implement draw_gradient_rect_full() in render.v
- [ ] Test 2-stop gradient (parity with current)
- [ ] Test 3-5 stop gradients
- [ ] Test linear gradient angles
- [ ] Test radial gradients
- [ ] Profile performance (baseline vs shader)
- [ ] Update gradient_border if needed

## Sources

**Architecture patterns verified from codebase:**
- shaders.v: Pipeline initialization pattern
- shaders_glsl.v, shaders_metal.v: Shader structure
- render.v: Renderer dispatch and draw functions
- window.v: Pipeline storage in Window struct

**Gradient rendering research:**
- [Shaders Explained: Gradients | MTLDoc](https://mtldoc.com/metal/2022/08/04/shaders-explained-gradients) - Metal gradient shader patterns
- [A flowing WebGL gradient, deconstructed](https://alexharri.com/blog/webgl-gradients) - Multi-stop gradient implementation
- [3 color gradient - Shadertoy](https://www.shadertoy.com/view/ttB3Rh) - Fragment shader gradient examples
- [Discussion: Multi-stop gradients - nanovg](https://github.com/memononen/nanovg/pull/430) - Texture vs uniform approaches
- [Linear Gradient - Godot Shaders](https://godotshaders.com/shader/linear-gradient/) - GLSL gradient patterns

**SDF rendering:**
- [2D Signed Distance Field Basics | Ronja's tutorials](https://www.ronja-tutorials.com/post/034-2d-sdf-basics/) - SDF fundamentals
- [Signed Distance Fields - GM Shaders](https://mini.gmshaders.com/p/sdf) - SDF shader patterns

**Sokol documentation:**
- [GitHub - floooh/sokol](https://github.com/floooh/sokol) - sokol.sgl immediate-mode API
- [sokol.sgl | vdoc](https://modules.vlang.io/sokol.sgl.html) - V language sokol bindings
