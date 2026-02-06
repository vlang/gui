# Custom Fragment Shader API

## Context

The framework has 4 hardcoded shader pipelines (rounded_rect, shadow,
blur, gradient). Adding new visual effects requires modifying framework
internals. A user-exposed API lets users attach custom fragment shaders
to views, making the framework extensible without core changes.

## Approach

Add a `CustomShader` config struct that holds GLSL + Metal fragment
source strings and 16 f32 uniforms. The framework provides the vertex
shader, handles pipeline creation/caching, and integrates into the
existing renderer dispatch pipeline.

## Key Constraints

- sokol.sgl only exposes `mvp` + `tm` (texture matrix) as uniforms
- `tm` gives 16 f32 values for user data
- Vertex attributes are fixed: position(float3), texcoord(float2),
  color(ubyte4n)
- Must supply both GLSL 330 and MSL sources (compile-time `$if macos`)
- Pipeline creation is expensive; must cache per unique shader

## Implementation

### 1. Add `CustomShader` struct to `styles.v` (after Gradient)

```v
pub struct CustomShader {
pub:
    fs_glsl  string   // GLSL 330 fragment source
    fs_metal string   // MSL fragment source
    uniforms [16]f32  // User data passed via tm matrix
}
```

Also add `custom_shader &CustomShader = unsafe { nil }` to
`ContainerStyle` and `RectangleStyle`.

### 2. Add field to `Shape` in `shape.v`

Add `custom_shader &CustomShader = unsafe { nil }` in the pointer
fields block (line 25, after `border_gradient`).

### 3. Add to view configs and thread through

**`view_container.v`** — Add `custom_shader` field to `ContainerCfg`
(line ~174, after `border_gradient`), thread through `ContainerView`
and `generate_layout` to `Shape.custom_shader`. Follow exact pattern
of `gradient` field.

**`view_rectangle.v`** — Add `custom_shader` to `RectangleCfg`
(line ~13, after `shadow`), pass through to internal container call.

### 4. Add vertex shaders in `shaders_glsl.v` and `shaders_metal.v`

Framework-provided vertex shaders that pass all 4 `tm` columns as
varyings (`u0..u3`). Same pattern as `vs_gradient_*` but with
generic naming. The position.z carries packed radius (same as other
pipelines).

**GLSL** (`vs_custom_glsl`):
```glsl
#version 330
layout(location=0) in vec3 position;
layout(location=1) in vec2 texcoord0;
layout(location=2) in vec4 color0;
uniform mat4 mvp;
uniform mat4 tm;
out vec2 uv;
out vec4 color;
out float params;
out vec4 u0, u1, u2, u3;
void main() {
    gl_Position = mvp * vec4(position.xy, 0.0, 1.0);
    uv = texcoord0;
    color = color0;
    params = position.z;
    u0 = tm[0]; u1 = tm[1]; u2 = tm[2]; u3 = tm[3];
}
```

**MSL** (`vs_custom_metal`): Same logic, Metal syntax. VertexOut
struct with `u0..u3` float4 fields.

### 5. Pipeline creation + draw function in `shaders.v`

**Hash function:**
```v
fn shader_cache_key(shader &CustomShader) u64 {
    return shader.fs_glsl.hash()
}
```

**`init_custom_shader_pipeline(shader, mut window)`:**
- Check `window.custom_shader_pips[key]`; return if cached
- Build pipeline identical to `init_gradient_pipeline` structure:
  same vertex layout, same uniform blocks, same blend state, same
  image/sampler setup
- Use `vs_custom_glsl`/`vs_custom_metal` as vertex shader
- Use `shader.fs_glsl`/`shader.fs_metal` as fragment shader
- Store in `window.custom_shader_pips[key]`

**`draw_custom_shader_rect(x, y, w, h, radius, shader, mut window)`:**
1. Get/create pipeline via `init_custom_shader_pipeline`
2. `sgl.matrix_mode_texture()` / `sgl.push_matrix()`
3. `sgl.load_matrix(&shader.uniforms[0])` — load 16 user floats
4. `sgl.load_pipeline(pip)`
5. `sgl.c4b(255, 255, 255, 255)` — white base vertex color
6. `z_val = pack_shader_params(radius * window.ui.scale, 0)`
7. `draw_quad(sx, sy, sw, sh, z_val)` (with scale applied)
8. `sgl.load_default_pipeline()` / pop matrix / restore modelview

### 6. Add renderer struct + dispatch in `render.v`

**New struct:**
```v
struct DrawCustomShader {
    x             f32
    y             f32
    w             f32
    h             f32
    radius        f32
    custom_shader &CustomShader
}
```

**Add `| DrawCustomShader`** to the `Renderer` sum type (line ~130).

**Add match arm** in `renderer_draw` (line ~238):
```v
DrawCustomShader {
    draw_custom_shader_rect(renderer.x, renderer.y, renderer.w,
        renderer.h, renderer.radius, renderer.custom_shader,
        mut window)
}
```

**Add dispatch** in `render_container` — insert before the gradient
check (line 356). Custom shader takes priority over gradient/blur:

```v
if shape.custom_shader != unsafe { nil } {
    window.renderers << DrawCustomShader{
        x:             shape.x
        y:             shape.y
        w:             shape.width
        h:             shape.height
        radius:        shape.radius
        custom_shader: shape.custom_shader
    }
} else if shape.gradient != unsafe { nil } {
    // existing gradient code...
```

Shadow rendering still happens before this (existing code), so
custom-shader views can still have drop shadows.

### 7. Add pipeline cache to `Window` in `window.v`

Add to `mut:` section (line ~51, after `gradient_pip_init`):
```v
custom_shader_pips map[u64]sgl.Pipeline
```

### 8. Example: `examples/custom_shader_demo.v`

Demonstrate a simple procedural effect (plasma, ripple, or color
cycling). The user sets `uniforms[0]` to elapsed time in an animation
callback to drive the effect.

## Fragment Shader Contract

User fragment shaders receive:

| Input    | Type      | Description                          |
|----------|-----------|--------------------------------------|
| `uv`     | vec2      | -1..1 centered coords               |
| `color`  | vec4      | Vertex color (white by default)      |
| `params` | float     | Packed radius (from position.z)      |
| `u0..u3` | vec4      | 16 user uniforms from tm matrix      |
| `tex`    | sampler2D | Dummy texture (must ref for sokol)   |

Output: `frag_color` (GLSL) or `return float4` (MSL).

Must include dummy texture workaround:
```glsl
if (frag_color.a < 0.0) { frag_color += texture(tex, uv); }
```

## Files Modified

| File               | Change                                  |
|--------------------|-----------------------------------------|
| `styles.v`         | `CustomShader` struct + style fields    |
| `shape.v`          | `custom_shader` pointer field           |
| `view_container.v` | Config field + threading to Shape       |
| `view_rectangle.v` | Config field + pass-through             |
| `shaders_glsl.v`   | `vs_custom_glsl` constant               |
| `shaders_metal.v`  | `vs_custom_metal` constant              |
| `shaders.v`        | Pipeline init, cache key, draw function |
| `render.v`         | `DrawCustomShader` + sum type + dispatch|
| `window.v`         | `custom_shader_pips` map field          |

## Verification

1. `v fmt -w` all modified files
2. `v -check-syntax` all modified files
3. Build + run `examples/custom_shader_demo.v` on macOS
4. Verify pipeline caching: two views with same shader source share
   one pipeline
5. Verify custom shader + shadow composition works
6. Run existing tests: `v test .`

## Unresolved Questions

- Custom shader replaces gradient/blur fill — should they compose?
- Should framework auto-inject time into a reserved uniform slot,
  or leave all 16 to user?
- Should border/stroke rendering work with custom shaders?
- Pipeline cache eviction needed, or unbounded map acceptable?
