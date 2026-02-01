# Phase 3: Radial Gradients - Research

**Researched:** 2026-02-01
**Domain:** Radial gradient shader implementation with CSS-compatible circular rendering
**Confidence:** HIGH

## Summary

Phase 3 extends the existing gradient shader infrastructure to support radial gradients. The core
algorithm computes distance from center to current pixel, normalizes by radius, and uses that as
the interpolation parameter `t`. The primary challenge is rendering perfect circles regardless of
element aspect ratio, which requires aspect ratio correction in the shader.

The existing gradient pipeline (Phase 1-2) provides the foundation: tm matrix for stop data, SDF
clipping for rounded corners, premultiplied alpha interpolation, and dithering. Phase 3 reuses
this infrastructure with a modified fragment shader that computes `t = length(uv * aspect) / radius`
instead of `t = dot(uv, dir) * 0.5 + 0.5`.

**Primary recommendation:** Start with centered circle using `closest-side` sizing (simpler math,
matches phase requirements). Pass aspect ratio via tm[3].zw. Shader computes normalized distance
from center. Position and size keywords can be added in future phases.

## Standard Stack

Phase 3 uses existing Phase 1-2 infrastructure. No new libraries.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| sokol.sgl | current | Immediate-mode API | Phase 1-2 foundation, tm matrix passing |
| GLSL/MSL | 330/3+ | Shader languages | Phase 1-2 shaders extended |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| V math module | current | length(), sqrt() | Only in V code if needed |
| GLSL length() | built-in | Distance computation | Shader distance from center |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `length(uv)` | `dot(uv, uv)` then sqrt | Equivalent, length() clearer |
| Centered gradient | User-defined center | Defer position to future phase |
| `closest-side` sizing | `farthest-corner` | closest-side simpler, matches "from center" requirement |

## Architecture Patterns

### Recommended Project Structure
```
styles.v              # Already has GradientType.radial, no changes needed
render.v              # Modify draw_gradient_rect to handle radial type
shaders_glsl.v        # Modify fs_gradient_glsl for radial t calculation
shaders_metal.v       # Modify fs_gradient_metal matching GLSL changes
```

### Pattern 1: Distance-Based Interpolation
**What:** Compute t from distance to center, normalized by radius
**When to use:** All radial gradients

Linear gradient (Phase 2):
```glsl
float t = dot(uv, dir) * 0.5 + 0.5;  // Project onto direction line
```

Radial gradient (Phase 3):
```glsl
float dist = length(uv);             // Distance from center (0,0)
float t = dist;                       // For centered, unit-radius gradient
t = clamp(t, 0.0, 1.0);
```

**Why this works:**
- UV ranges from -1 to 1 (centered coordinate system per draw_quad)
- length(uv) gives distance from center
- At center: t=0 (first color)
- At edge: t=1 (last color) when properly normalized

### Pattern 2: Perfect Circle via Aspect Ratio Correction
**What:** Scale UV coordinates to ensure circles don't stretch on non-square elements
**When to use:** Always for radial gradients with `circle` shape

Problem: A 200x100 element with UV -1..1 would render an ellipse, not a circle.

Solution: Pass aspect ratio to shader, correct UV before computing distance.

```glsl
// Aspect correction for perfect circles
// aspect = vec2(1.0, width/height) for width >= height
// aspect = vec2(height/width, 1.0) for height > width
vec2 corrected_uv = uv * aspect;
float dist = length(corrected_uv);
```

For a 200x100 element:
- aspect = vec2(1.0, 2.0)
- UV (1, 0.5) becomes (1.0, 1.0) after correction
- Circle touches shortest edge (top/bottom at 50px from center)

### Pattern 3: Closest-Side Sizing (Default for Phase 3)
**What:** Gradient radius extends to the closest edge
**When to use:** Default behavior for MVP

CSS `closest-side` means:
- Circle: radius = min(half_width, half_height)
- At closest edge, t=1.0 (100%)
- Center is t=0.0 (0%)

Implementation:
```glsl
// In shader, aspect correction makes UV normalized so length(uv)=1.0 at closest edge
// No explicit radius needed - just normalize t to 0..1
float t = length(uv * aspect);
```

V code computes aspect:
```v
// For closest-side sizing
aspect_x := if sw >= sh { f32(1.0) } else { sw / sh }
aspect_y := if sh >= sw { f32(1.0) } else { sh / sw }
```

### Pattern 4: Passing Radial Parameters via tm[3]
**What:** Pack radial gradient metadata into tm matrix column 3
**When to use:** All radial gradient renders

tm matrix layout for radial:
- tm[0]: stop1 (r, g, b, pos)
- tm[1]: stop2 (r, g, b, pos)
- tm[2]: stop3 (r, g, b, pos)
- tm[3]: radial params (aspect_x, aspect_y, gradient_type, reserved)

```v
// In draw_gradient_rect for radial
if gradient.type == .radial {
    aspect_x := if sw >= sh { f32(1.0) } else { sw / sh }
    aspect_y := if sh >= sw { f32(1.0) } else { sh / sw }
    tm_data[12] = aspect_x  // tm[3].x
    tm_data[13] = aspect_y  // tm[3].y
    tm_data[14] = 1.0       // Flag: radial mode (vs 0.0 for linear)
    tm_data[15] = 1.0
}
```

Shader reads:
```glsl
vec2 aspect = stop_dir;  // Reuse existing varying (renamed conceptually)
float is_radial = stop3.a > 0.5 ? 1.0 : 0.0;  // Or use tm[3].z if passed
```

### Pattern 5: Unified Shader with Gradient Type Branch
**What:** Single fragment shader handles both linear and radial
**When to use:** Keep one pipeline, branch on type

Option A (recommended): Branch in shader based on tm[3].z flag
```glsl
float t;
if (stop_params.z > 0.5) {
    // Radial: distance from center
    vec2 aspect = stop_params.xy;
    t = length(uv * aspect);
} else {
    // Linear: project onto direction
    vec2 dir = stop_params.xy;
    t = dot(uv, dir) * 0.5 + 0.5;
}
t = clamp(t, 0.0, 1.0);
```

Option B: Separate radial pipeline
- More shader code duplication
- Separate pipeline init
- Cleaner separation but more maintenance

**Recommendation:** Option A for MVP. Gradient type flag in tm[3].z keeps single pipeline.

### Anti-Patterns to Avoid
- **Forgetting aspect correction:** Results in ellipse instead of circle on non-square elements
- **Using raw length(uv):** Without aspect correction, circles stretch
- **Computing sqrt in V code:** length() in shader is optimized, let GPU handle it

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Distance computation | Manual sqrt(x*x+y*y) | GLSL length() | GPU-optimized, single instruction on many GPUs |
| Circle aspect correction | Per-pixel division | Pre-computed aspect ratio | Avoid division in hot loop |
| Gradient type dispatch | Separate draw functions | tm[3].z flag + shader branch | Single pipeline, less code |

**Key insight:** Radial gradients are simpler than linear in some ways (no direction vector, just
distance). The main complexity is aspect ratio handling for perfect circles.

## Common Pitfalls

### Pitfall 1: Ellipse Instead of Circle on Non-Square Elements
**What goes wrong:** Radial gradient stretches to fill element, creating ellipse
**Why it happens:** Using raw UV coordinates without aspect correction
**How to avoid:**
```glsl
// WRONG: ellipse on non-square
float t = length(uv);

// RIGHT: perfect circle via aspect correction
vec2 aspect = vec2(aspect_x, aspect_y);  // From tm[3].xy
float t = length(uv * aspect);
```
**Warning signs:** Circle appears stretched horizontally or vertically

### Pitfall 2: Wrong Aspect Ratio Direction
**What goes wrong:** Circle clips at wrong edges
**Why it happens:** Aspect ratio computed incorrectly (multiplied vs divided)
**How to avoid:**
```v
// For closest-side: scale the LONGER axis
// If width > height, scale x to make it "shorter" in UV space
aspect_x := if sw >= sh { f32(1.0) } else { sw / sh }
aspect_y := if sh >= sw { f32(1.0) } else { sh / sw }
```
**Warning signs:** Circle touches long edges instead of short edges

### Pitfall 3: t Range Mismatch
**What goes wrong:** Colors don't distribute as expected
**Why it happens:** Stop positions expect t in 0..1, but distance not normalized
**How to avoid:**
```glsl
// After aspect correction, length(uv*aspect) is 1.0 at closest edge
// So t naturally ranges 0..1 for closest-side sizing
float t = clamp(length(uv * aspect), 0.0, 1.0);
```
**Warning signs:** Gradient ends before reaching edge, or first/last colors don't appear at
center/edge

### Pitfall 4: Breaking Linear Gradients
**What goes wrong:** Adding radial support breaks existing linear gradients
**Why it happens:** Changing tm[3] usage without backward compatibility
**How to avoid:**
```glsl
// tm[3].z as type flag: 0.0 = linear (default), 1.0 = radial
// Existing linear gradients have tm[3].z = 0.0 (from identity matrix padding)
float is_radial = stop_params.z > 0.5 ? 1.0 : 0.0;
```
**Warning signs:** Linear gradients stop working after radial changes

### Pitfall 5: Edge Color Beyond Bounds
**What goes wrong:** Unexpected color at element edges for radial
**Why it happens:** t > 1.0 at corners of element
**How to avoid:**
```glsl
// Clamp ensures last color extends to corners
t = clamp(t, 0.0, 1.0);
// At corner of 200x100 element with closest-side:
// Corner UV = (1, 1), aspect = (1, 2), corrected = (1, 2)
// length = sqrt(1+4) = 2.24, clamped to 1.0 = last color
```
**Warning signs:** Different color at corners than expected

## Code Examples

### Fragment Shader Update (GLSL)
```glsl
// Source: Modified from existing fs_gradient_glsl
// In fs_gradient_glsl, replace t calculation section:

// Read radial params from tm[3]
// stop_dir.xy = aspect (for radial) or direction (for linear)
// stop_dir is passed from VS as tm[3].xy

// Determine gradient type (0 = linear, 1 = radial)
// Could use a separate varying or pack into stop3
// For MVP: detect radial if aspect.x != direction pattern
// Better: explicit flag in tm[3].z passed as varying

float t;
// Linear gradient: project onto direction
vec2 dir = stop_dir;
t = dot(uv, dir) * 0.5 + 0.5;

// For radial (in separate block or branch):
// vec2 aspect = stop_dir;  // aspect correction values
// t = length(uv * aspect); // distance from center, normalized

t = clamp(t, 0.0, 1.0);
// Rest of multi-stop interpolation unchanged
```

### Radial Distance Calculation (GLSL)
```glsl
// Radial gradient t calculation
// Assumes stop_dir contains (aspect_x, aspect_y) for radial mode

vec2 aspect = stop_dir;
float t = length(uv * aspect);  // Distance from center
t = clamp(t, 0.0, 1.0);         // Clamp for corners beyond radius
```

### V Code: Compute Aspect Ratio
```v
// Source: render.v draw_gradient_rect modification
fn draw_gradient_rect(x f32, y f32, w f32, h f32, radius f32, gradient &Gradient, mut window Window) {
    // ... existing scale and bounds code ...

    // Pack stops into tm[0..2] (existing code)
    // ...

    // tm[3] content depends on gradient type
    if gradient.type == .radial {
        // Aspect ratio for perfect circles (closest-side sizing)
        aspect_x := if sw >= sh { f32(1.0) } else { sw / sh }
        aspect_y := if sh >= sw { f32(1.0) } else { sh / sw }
        tm_data[12] = aspect_x  // tm[3].x
        tm_data[13] = aspect_y  // tm[3].y
        tm_data[14] = 1.0       // Radial flag
        tm_data[15] = 1.0
    } else {
        // Linear gradient (existing code)
        dx, dy := gradient_direction(gradient, sw, sh)
        tm_data[12] = dx
        tm_data[13] = dy
        tm_data[14] = 0.0       // Linear flag
        tm_data[15] = 1.0
    }

    // ... rest of existing code ...
}
```

### Metal Fragment Shader (Radial Section)
```metal
// Source: Modified from existing fs_gradient_metal
// Radial gradient calculation (for reference)

float2 aspect = in.stop_dir;
float t = length(in.uv * aspect);
t = clamp(t, 0.0, 1.0);

// Multi-stop interpolation unchanged from linear
```

### Complete Unified Shader Pattern
```glsl
// Unified t calculation supporting both linear and radial
// stop_dir.xy = direction (linear) or aspect (radial)
// is_radial flag from tm[3].z (passed as varying or encoded)

float t;
float is_radial = /* from tm[3].z or derived */;

if (is_radial > 0.5) {
    // Radial: distance from center with aspect correction
    vec2 aspect = stop_dir;
    t = length(uv * aspect);
} else {
    // Linear: project onto direction vector
    vec2 dir = stop_dir;
    t = dot(uv, dir) * 0.5 + 0.5;
}
t = clamp(t, 0.0, 1.0);

// Multi-stop interpolation (unchanged)
// ...
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Separate radial pipeline | Unified gradient pipeline with type flag | Modern practice | Single pipeline, less maintenance |
| Ellipse default | Circle with aspect correction | CSS Images 3 | Perfect circles on any aspect ratio |
| Center-only position | CSS at <position> | CSS Images 3 | Flexibility (defer to future phase) |

**Deprecated/outdated:**
- Drawing ellipse and calling it "radial": CSS spec allows ellipse but circle is the common case
- Ignoring aspect ratio: Results in stretched gradients

## Open Questions

1. **Gradient type flag passing**
   - What we know: tm[3].z available (was 0.0, can be set to 1.0 for radial)
   - What's unclear: Need new varying or can reuse existing stop_dir structure?
   - Recommendation: Add `float gradient_type` varying, set from tm[3].z in VS

2. **Center position support**
   - What we know: CSS supports `at <position>` syntax
   - What's unclear: How to pass center offset (tm[3] slots limited)
   - Recommendation: Defer to future phase; MVP uses center (0,0) only

3. **Size keyword support**
   - What we know: CSS has closest-side, farthest-corner, etc.
   - What's unclear: How much complexity to add in MVP
   - Recommendation: MVP implements closest-side only (matches "from center" requirement)

4. **Ellipse support**
   - What we know: CSS allows `ellipse` shape
   - What's unclear: User need for ellipse vs circle
   - Recommendation: Defer ellipse to future; circle covers most UI needs

## Sources

### Primary (HIGH confidence)
- [MDN radial-gradient()](https://developer.mozilla.org/en-US/docs/Web/CSS/gradient/radial-gradient) - CSS spec behavior
- [Patrick Brosset: CSS Radial Gradients](https://patrickbrosset.com/articles/2022-10-24-do-you-really-understand-CSS-radial-gradients/) - Sizing mechanics
- v-gui codebase: shaders_glsl.v, shaders_metal.v, render.v - Existing gradient infrastructure
- Phase 1-2 RESEARCH.md - Foundation patterns

### Secondary (MEDIUM confidence)
- [Godot Shaders: Radial Gradient](https://godotshaders.com/shader/radial-smooth-radial-gradient/) - Shader distance pattern
- [Agate Dragon: Circular Gradient](https://agatedragon.blog/2024/04/07/shadertoy-circle-gradient/) - Aspect correction technique
- [CSS-Tricks: radial-gradient()](https://css-tricks.com/almanac/functions/r/radial-gradient/) - Size keywords

### Tertiary (LOW confidence)
- [Shadertoy aspect ratio tutorial](https://www.shadertoy.com/view/slXXW4) - Referenced but not fetched

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Uses existing Phase 1-2 infrastructure
- Architecture: HIGH - Distance-based gradient well-established, aspect correction standard technique
- Pitfalls: HIGH - Common issues documented, existing codebase patterns reduce risk

**Research date:** 2026-02-01
**Valid until:** 60 days (stable CSS spec, shader math well-established)

**Phase 3 specific focus:**
Circular radial gradients from center with closest-side sizing. Ellipse, position keywords, and
size keywords (farthest-corner, etc.) are deferred to future phases.
