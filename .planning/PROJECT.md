# v-gui Gradient Rendering

## What This Is

Complete gradient rendering support for the v-gui framework. Multi-stop linear gradients with CSS
direction control, circular radial gradients, premultiplied alpha interpolation, and dithering.

## Core Value

Gradients render correctly with arbitrary color stops — no visual artifacts, no 2-color hacks.

## Requirements

### Validated

- ✓ 2-color linear gradient (corner interpolation) — existing hack (superseded)
- ✓ Shader pipeline exists (Metal/GLSL) — existing infrastructure
- ✓ Gradient struct defined in styles.v — existing API
- ✓ Multi-stop linear gradients with arbitrary stops — v1.0
- ✓ CSS-compatible gradient angle/direction handling — v1.0
- ✓ Radial gradients (circular) — v1.0
- ✓ Fragment shader replaces vertex interpolation — v1.0
- ✓ Dithering prevents color banding — v1.0
- ✓ Premultiplied alpha interpolation — v1.0

### Active

(Next milestone requirements defined via `/gsd:new-milestone`)

### Out of Scope

- Angular/conic gradients — lower priority, defer
- Gradient animation — separate concern, future work
- Repeating gradients — can add later if needed

## Context

**Current state:** v1.0 shipped with ~26K LOC V language.
Tech stack: V, sokol/sgl, Metal (macOS), GLSL (Linux/Windows).
Gradient pipeline: gradient_pip following shadow_pip pattern.
Multi-stop limit: 3 stops (tm matrix capacity).

**What shipped:**
- GLSL + Metal gradient shaders with vs_gradient/fs_gradient
- draw_gradient_rect API in render.v
- Direction enum (8 CSS keywords) + angle field
- Radial type flag (tm[3].z) + aspect ratio packing

## Constraints

- **Tech stack**: V language, sokol/gg graphics — must work within existing pipeline
- **Cross-platform**: Must work on Metal (macOS) and GLSL (Linux/Windows)
- **Performance**: Gradients used frequently; can't tank frame rate

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Fragment shader vs texture approach | Researched both; fragment shader simpler for variable stops | ✓ Good |
| tm matrix packing for stops | 4x4 matrix carries 3 stops as vec4(r,g,b,pos) | ✓ Good |
| Premultiplied alpha interpolation | CSS spec requirement, prevents gray artifacts | ✓ Good |
| Screen-space dithering | fract(sin(dot(...))) noise breaks 8-bit banding | ✓ Good |
| Direction vector in tm[3].xy | Shader reads direction from uniform matrix | ✓ Good |
| Type flag in tm[3].z | 1.0=radial, 0.0=linear; single shader handles both | ✓ Good |
| Aspect ratio for radial circles | Longer axis = 1.0, shorter = ratio | ✓ Good |

---
*Last updated: 2026-02-01 after v1.0 milestone*
