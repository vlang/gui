# Phase 2: Linear Gradients - Research

**Researched:** 2026-02-01
**Domain:** Linear gradient direction/angle control with CSS-compatible behavior
**Confidence:** HIGH

## Summary

Phase 2 adds direction control to the existing fragment shader gradient system. The core algorithm is
straightforward: convert angle to direction vector, project UV coordinates onto gradient line, use
result as interpolation parameter `t`. CSS conventions (0deg=top, clockwise) and corner keyword
aspect-ratio adjustment are well-documented standards.

The existing gradient shader already computes `t = uv.x * 0.5 + 0.5` for horizontal gradients. Phase
2 replaces this with `t = dot(uv, direction) * 0.5 + 0.5` where `direction` is derived from angle.
Corner keywords require aspect-ratio-aware angle calculation using `atan(width/height)`.

**Primary recommendation:** Pass angle via tm[3].xy (cos, sin of angle), compute direction in
fragment shader using element aspect ratio from existing UV-to-pixel conversion. Default 180deg
(to_bottom) matches CSS.

## Standard Stack

Phase 2 uses existing Phase 1 infrastructure. No new libraries.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| sokol.sgl | current | Immediate-mode API | Phase 1 foundation, tm matrix passing |
| GLSL/MSL | 330/3+ | Shader languages | Phase 1 shaders extended |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| V math module | current | Angle conversion | radians(), sin(), cos() in V code |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| tm[3] for angle | z-coordinate packing | z already used for radius+stop_count; tm[3] available |
| cos/sin in V | Pass angle to shader | Avoid shader trig functions on hot path |
| Aspect ratio in V | Compute in shader | Shader already has uv_to_px for aspect info |

## Architecture Patterns

### Recommended Project Structure
```
styles.v              # Add Direction enum, angle field to Gradient struct
render.v              # Precompute direction, pack into tm[3]
shaders_glsl.v        # Modify fs_gradient_glsl for directional t calculation
shaders_metal.v       # Modify fs_gradient_metal matching GLSL changes
```

### Pattern 1: Angle to Direction Vector
**What:** Convert CSS angle to unit direction vector
**When to use:** Any angle-based gradient

CSS angles: 0deg=top, clockwise rotation
- 0deg -> direction (0, -1) -> gradient flows upward (to top)
- 90deg -> direction (1, 0) -> gradient flows rightward (to right)
- 180deg -> direction (0, 1) -> gradient flows downward (to bottom)
- 270deg -> direction (-1, 0) -> gradient flows leftward (to left)

**Conversion formula:**
```v
// CSS angle to direction vector
// CSS: 0deg = to top, clockwise
// Math: 0 rad = to right, counter-clockwise
// Conversion: math_angle = (90 - css_angle) in degrees, or (PI/2 - css_radians)
fn angle_to_direction(css_degrees f32) (f32, f32) {
    rad := (90.0 - css_degrees) * math.pi / 180.0
    return math.cosf(rad), math.sinf(rad)
}
```

**Example:**
```v
// 45deg (to top-right diagonal)
dx, dy := angle_to_direction(45.0)  // (0.707, -0.707)
```

### Pattern 2: Corner Keyword to Angle
**What:** Convert CSS corner keywords to angle based on element aspect ratio
**When to use:** Direction specified as to_top_right, to_bottom_left, etc.

CSS corner gradients point TO the actual corner, regardless of aspect ratio. The angle is computed
from element dimensions:

```v
// to_top_right: gradient line points from center to top-right corner
// The perpendicular passes through top-left and bottom-right corners
fn corner_to_angle(keyword Direction, width f32, height f32) f32 {
    match keyword {
        .to_top         => 0.0
        .to_right       => 90.0
        .to_bottom      => 180.0
        .to_left        => 270.0
        .to_top_right   => 90.0 - math.atan2f(height, width) * 180.0 / math.pi
        .to_bottom_right=> 90.0 + math.atan2f(height, width) * 180.0 / math.pi
        .to_bottom_left => 270.0 - math.atan2f(height, width) * 180.0 / math.pi
        .to_top_left    => 270.0 + math.atan2f(height, width) * 180.0 / math.pi
    }
}
```

For a square (width=height): to_top_right = 45deg
For 2:1 rectangle: to_top_right = 90 - atan(1/2) = 90 - 26.57 = 63.43deg

### Pattern 3: Gradient Position Calculation (Shader)
**What:** Project UV onto gradient line to get interpolation factor t
**When to use:** Fragment shader gradient computation

Current Phase 1 code:
```glsl
float t = uv.x * 0.5 + 0.5;  // Horizontal only
```

Phase 2 replacement:
```glsl
// dir.xy = direction vector (from tm[3].xy)
// Project uv onto direction, normalize to 0..1
float t = dot(uv, dir) * 0.5 + 0.5;
```

**Why this works:**
- UV ranges from -1 to 1 (centered coordinate system per draw_quad)
- dot(uv, dir) projects uv onto direction line
- Range is -1..1 (diagonal of centered square)
- `* 0.5 + 0.5` maps to 0..1

### Pattern 4: Gradient Line Extension (CSS "Magic Corners")
**What:** Gradient line extends beyond element to ensure corner coverage
**When to use:** All linear gradients

CSS spec: gradient endpoints are NOT at element edges. They're at perpendicular intersections from
corners. This ensures pure start/end colors exactly at the nearest corners.

For shader implementation: The dot product naturally handles this. When uv is at a corner
(e.g., -1,-1), dot(uv, dir) gives the projection distance. The 0..1 normalization from stop
positions handles the rest.

No explicit endpoint extension needed in shader math.

### Pattern 5: Passing Direction to Shader
**What:** Pack direction vector into tm matrix column 3
**When to use:** All gradient renders

tm matrix layout (column-major):
- tm[0]: stop1 (r, g, b, pos)
- tm[1]: stop2 (r, g, b, pos)
- tm[2]: stop3 (r, g, b, pos)
- tm[3]: direction data (cos_angle, sin_angle, 0, 1)

```v
// In draw_gradient_rect after stop packing
dx, dy := angle_to_direction(gradient.angle)
tm_data[12] = dx  // tm[3].x = cos(math_angle)
tm_data[13] = dy  // tm[3].y = sin(math_angle)
tm_data[14] = 0.0
tm_data[15] = 1.0
```

Shader reads:
```glsl
vec2 dir = stop_dir.xy;  // Passed as varying from VS (tm[3].xy)
```

### Anti-Patterns to Avoid
- **Computing sin/cos in fragment shader per-pixel:** Expensive; precompute in V code
- **Ignoring aspect ratio for corners:** to_top_right must point to actual corner, not 45deg
- **Flipping Y-axis inconsistently:** v-gui uses screen coords (Y down), match CSS convention

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Angle normalization | Manual modulo | `fmod(angle, 360.0)` then handle negatives | Edge cases (negative angles, >360) |
| Corner aspect calculation | Hardcoded angles | `atan2(h,w)` formula | Works for any aspect ratio |
| Gradient endpoint extension | Manual endpoint math | Dot product projection | CSS "magic corners" handled implicitly |

**Key insight:** CSS gradient math is simple once you understand the dot product projection. Don't
overcomplicate with explicit line-segment intersection calculations.

## Common Pitfalls

### Pitfall 1: CSS vs Math Angle Convention
**What goes wrong:** Gradient points wrong direction
**Why it happens:** CSS 0deg=top (north), math 0rad=right (east). CSS is clockwise, math is
counter-clockwise.
**How to avoid:**
```v
// Always convert: math_angle = 90 - css_angle (in degrees)
rad := (90.0 - css_degrees) * math.pi / 180.0
```
**Warning signs:** 0deg gradient goes right instead of up; 90deg goes up instead of right

### Pitfall 2: Y-Axis Direction Mismatch
**What goes wrong:** Gradient appears flipped vertically on different platforms
**Why it happens:** OpenGL Y=0 at bottom, screen coords Y=0 at top. Metal and v-gui use top-left
origin.
**How to avoid:** v-gui already uses screen coordinates throughout. UV -1,-1 = top-left,
UV 1,1 = bottom-right. CSS "to top" means toward smaller Y (toward screen top), which is negative
UV.y direction. Current formula handles this correctly.
**Warning signs:** "to bottom" renders as "to top"

### Pitfall 3: Corner Gradient Wrong Angle for Non-Square
**What goes wrong:** to_top_right shows 45deg diagonal instead of pointing at actual corner
**Why it happens:** Using hardcoded 45deg instead of atan2-based calculation
**How to avoid:** Always compute corner angles from element dimensions
**Warning signs:** Diagonal gradients look "off" on wide/tall elements

### Pitfall 4: Direction Vector Not Normalized
**What goes wrong:** Gradient appears stretched or compressed
**Why it happens:** Using non-unit direction vector
**How to avoid:** cos/sin always produce unit vector; no normalization needed if using angle
conversion
**Warning signs:** Gradient color distribution doesn't match stop positions

### Pitfall 5: Angle Normalization Edge Cases
**What goes wrong:** Negative angles or angles >360 produce unexpected results
**Why it happens:** Not normalizing input before conversion
**How to avoid:**
```v
fn normalize_angle(deg f32) f32 {
    mut a := math.fmod(deg, 360.0)
    if a < 0 { a += 360.0 }
    return a
}
```
**Warning signs:** -45deg behaves differently than 315deg

## Code Examples

### Direction Enum (V)
```v
// Source: CSS linear-gradient spec keywords
pub enum Direction {
    to_top
    to_top_right
    to_right
    to_bottom_right
    to_bottom
    to_bottom_left
    to_left
    to_top_left
}
```

### Updated Gradient Struct (V)
```v
pub struct Gradient {
pub:
    stops     []GradientStop
    direction Direction = .to_bottom  // CSS default
    angle     ?f32                     // Optional: explicit angle overrides direction
    // Deprecated: start_x, start_y, end_x, end_y (replaced by direction/angle)
}
```

### Angle Conversion (V)
```v
// Source: CSS spec + standard trig
fn gradient_direction(gradient &Gradient, width f32, height f32) (f32, f32) {
    // If explicit angle provided, use it
    if angle := gradient.angle {
        return angle_to_direction(angle)
    }

    // Otherwise convert direction keyword to angle
    css_angle := match gradient.direction {
        .to_top         => 0.0
        .to_right       => 90.0
        .to_bottom      => 180.0
        .to_left        => 270.0
        .to_top_right   => 90.0 - math.atan2f(height, width) * 180.0 / math.pi
        .to_bottom_right=> 90.0 + math.atan2f(height, width) * 180.0 / math.pi
        .to_bottom_left => 270.0 - math.atan2f(height, width) * 180.0 / math.pi
        .to_top_left    => 270.0 + math.atan2f(height, width) * 180.0 / math.pi
    }
    return angle_to_direction(css_angle)
}

fn angle_to_direction(css_degrees f32) (f32, f32) {
    // CSS: 0deg=top, clockwise. Math: 0rad=right, counter-clockwise.
    rad := (90.0 - css_degrees) * math.pi / 180.0
    return math.cosf(rad), math.sinf(rad)
}
```

### Fragment Shader Update (GLSL)
```glsl
// Source: CSS linear-gradient projection algorithm
// In vs_gradient_glsl, add:
out vec2 stop_dir;  // Direction vector from tm[3]
// ...
stop_dir = tm[3].xy;

// In fs_gradient_glsl, replace t calculation:
// Old: float t = uv.x * 0.5 + 0.5;
// New:
vec2 dir = stop_dir;  // Unit direction vector
float t = dot(uv, dir) * 0.5 + 0.5;
t = clamp(t, 0.0, 1.0);  // Ensure within bounds (non-repeating)
```

### Fragment Shader Update (Metal)
```metal
// Source: CSS linear-gradient projection algorithm
// In VertexOut struct, add:
float2 stop_dir;

// In vs_main, add:
out.stop_dir = uniforms.tm[3].xy;

// In fs_main, replace t calculation:
float2 dir = in.stop_dir;
float t = dot(in.uv, dir) * 0.5 + 0.5;
t = clamp(t, 0.0, 1.0);
```

### Updated draw_gradient_rect (V)
```v
fn draw_gradient_rect(x f32, y f32, w f32, h f32, radius f32, gradient &Gradient, mut window Window) {
    // ... existing scale and bounds code ...

    // Pack stops into tm[0..2] (existing code)
    // ...

    // Compute direction vector and pack into tm[3]
    dx, dy := gradient_direction(gradient, sw, sh)
    tm_data[12] = dx
    tm_data[13] = dy
    tm_data[14] = 0.0
    tm_data[15] = 1.0

    // ... rest of existing code ...
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| start_x/end_x point pairs | CSS angle/keyword | CSS Images 3 (2012) | Simpler API, matches web standards |
| Vertex color interpolation | Fragment shader projection | Phase 1 (2026) | Multi-stop + arbitrary angle support |

**Deprecated/outdated:**
- Gradient struct start_x/start_y/end_x/end_y: Replaced by direction enum and angle field

## Open Questions

1. **Angle field data type**
   - What we know: CSS uses degrees as primary unit, internally convert to radians
   - What's unclear: Should V API accept degrees (CSS-like) or radians (math-like)?
   - Recommendation: Use degrees for CSS compatibility; convert internally

2. **Conflict resolution (angle + direction both specified)**
   - What we know: CSS doesn't allow both; only angle OR keyword
   - What's unclear: V API using optional angle (?f32) vs explicit union type
   - Recommendation: Optional angle overrides direction if present; document clearly

3. **Default direction validation**
   - What we know: CSS default is `to bottom` (180deg)
   - What's unclear: Current Gradient struct has start_x=0, end_x=1 (to_right), inconsistent
   - Recommendation: Change default to .to_bottom, deprecate start/end fields

## Sources

### Primary (HIGH confidence)
- [MDN linear-gradient() reference](https://developer.mozilla.org/en-US/docs/Web/CSS/gradient/linear-gradient) - Official CSS spec behavior
- [9elements Gradient Angles](https://9elements.com/blog/gradient-angles-in-css-figma-and-sketch/) - Corner angle math
- v-gui codebase: shaders.v draw_quad UV mapping, render.v gradient stop packing

### Secondary (MEDIUM confidence)
- [Godot Shaders Linear Gradient](https://godotshaders.com/shader/linear-gradient/) - Shader rotation formula verified
- [MTLDoc Gradient Shaders](https://mtldoc.com/metal/2022/08/04/shaders-explained-gradients) - UV-based gradient approach

### Tertiary (LOW confidence)
- WebSearch results on CSS gradient math - General patterns, verified against MDN

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Uses existing Phase 1 infrastructure, no new dependencies
- Architecture: HIGH - CSS spec is authoritative, shader math is well-established
- Pitfalls: HIGH - Common issues well-documented, coordinate system verified in codebase

**Research date:** 2026-02-01
**Valid until:** 60 days (stable CSS spec, no breaking changes expected)

**Phase 2 specific focus:**
Linear direction/angle only. Radial gradients, repeating gradients, conic gradients are separate
phases.
