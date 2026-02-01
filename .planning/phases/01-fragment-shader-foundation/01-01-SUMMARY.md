---
phase: 01-fragment-shader-foundation
plan: 01
subsystem: rendering
tags: [glsl, metal, shaders, gradients, gpu, fragment-shader, sdf]

# Dependency graph
requires:
  - phase: none
    provides: initial codebase with shadow/blur shader patterns
provides:
  - GLSL gradient vertex and fragment shaders (vs_gradient_glsl, fs_gradient_glsl)
  - Metal gradient vertex and fragment shaders (vs_gradient_metal, fs_gradient_metal)
  - Multi-stop interpolation algorithm (3 stops via tm matrix)
  - Premultiplied alpha interpolation preventing gray artifacts
  - Dithering preventing color banding
  - SDF rounded rect clipping integrated in fragment shader
affects: [02-pipeline-integration, 03-public-api]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Fragment shader multi-stop gradient interpolation via tm uniform matrix
    - Premultiplied alpha color space for artifact-free transparency blending
    - Dithering via screen-space random function to prevent 8-bit banding

key-files:
  created: []
  modified:
    - shaders_glsl.v
    - shaders_metal.v

key-decisions:
  - "tm matrix rows (GLSL) / columns (Metal) pack 3 gradient stops as vec4(r,g,b,pos)"
  - "Premultiplied alpha interpolation prevents gray artifacts on transparent gradients"
  - "Dithering adds screen-space noise before 8-bit quantization to break up banding"

patterns-established:
  - "Gradient position t computed from uv.x mapped -1..1 to 0..1"
  - "Multi-stop segment detection: if t <= stop2.pos then interpolate [stop1,stop2] else [stop2,stop3]"
  - "Random function using fract(sin(dot(...))) for dithering noise"

# Metrics
duration: 1min
completed: 2026-02-01
---

# Phase 1 Plan 01: Fragment Shader Foundation Summary

**GLSL and Metal fragment shaders computing 3-stop gradients with premultiplied alpha interpolation and dithering**

## Performance

- **Duration:** 1 min
- **Started:** 2026-02-01T18:02:49Z
- **Completed:** 2026-02-01T18:04:11Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- GLSL gradient shaders (vs_gradient_glsl, fs_gradient_glsl) with multi-stop interpolation
- Metal gradient shaders (vs_gradient_metal, fs_gradient_metal) with multi-stop interpolation
- Premultiplied alpha interpolation preventing gray artifacts on transparency
- Dithering preventing visible color banding in gradients
- SDF rounded rect clipping integrated for shape boundaries

## Task Commits

Each task was committed atomically:

1. **Task 1: Create GLSL gradient shaders** - `315bffe` (feat)
2. **Task 2: Create Metal gradient shaders** - `c49da2e` (feat)

## Files Created/Modified
- `shaders_glsl.v` - vs_gradient_glsl and fs_gradient_glsl shader source strings
- `shaders_metal.v` - vs_gradient_metal and fs_gradient_metal shader source strings

## Decisions Made

**tm matrix packing:** tm[0], tm[1], tm[2] store gradient stops as vec4(r,g,b,pos). GLSL uses rows, Metal uses columns (column-major). Supports 3 stops in MVP, expandable to 4 if needed.

**Premultiplied alpha interpolation:** Interpolate RGB in premultiplied space (rgb*a) then unpremultiply after blending. Prevents desaturation/gray artifacts when fading to transparency (CSS gradient spec requirement).

**Dithering algorithm:** Screen-space random noise (fract(sin(dot(...)))) scaled to ±0.5/255.0 added before 8-bit quantization. Breaks up visible banding in low-contrast gradients.

**SDF integration:** Reused existing rounded_box_sdf pattern from fs_glsl/fs_metal. Gradient color multiplied by SDF alpha for shape clipping.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Ready for Phase 1 Plan 02 (Pipeline Integration):**
- Shader source strings complete and syntax-validated
- vs_gradient_glsl/fs_gradient_glsl ready for GLSL pipeline init
- vs_gradient_metal/fs_gradient_metal ready for Metal pipeline init
- tm uniform structure defined (4x4 matrix for stop data)
- params packing convention established (radius in high 3 digits, stop_count in low 3)

**No blockers.** Shaders follow existing shadow_pip/blur_pip patterns exactly, ready for pipeline init in shaders.v.

---
*Phase: 01-fragment-shader-foundation*
*Completed: 2026-02-01*
