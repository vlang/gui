---
phase: 01-fragment-shader-foundation
plan: 03
subsystem: rendering
tags: [gradient, sgl, sokol, fragment-shader, dithering, premultiplied-alpha]

# Dependency graph
requires:
  - phase: 01-01
    provides: GLSL and Metal gradient shader source strings
  - phase: 01-02
    provides: gradient_pip pipeline infrastructure and init_gradient_pipeline()
provides:
  - draw_gradient_rect using fragment shader pipeline
  - Multi-stop gradient support (up to 3 stops)
  - Dithered gradient output (anti-banding)
  - Premultiplied alpha interpolation
affects: [03-public-api, gradient-based-widgets]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Varying-based stop data passing (VS packs, FS interpolates)
    - tm matrix as stop data carrier via sgl.matrix_mode_texture()
    - z-coordinate packing for radius and stop_count params

key-files:
  created: []
  modified:
    - render.v
    - shaders_glsl.v
    - shaders_metal.v

key-decisions:
  - "Pass stop data via varyings (VS->FS) instead of FS uniforms for reliability"
  - "Pack stop data into tm matrix columns (column-major for sokol/Metal)"
  - "Use slice syntax for sgl.mult_matrix: &tm_data[0..]"

patterns-established:
  - "Gradient stops packed in tm[0..2] columns as vec4(r,g,b,pos)"
  - "Vertex shader reads tm matrix, passes to fragment via varyings"
  - "stop_count passed via z-coordinate packed with radius"

# Metrics
duration: 15min
completed: 2026-02-01
---

# Phase 1 Plan 03: Wire draw_gradient_rect Summary

**Fragment shader gradient pipeline active, replacing vertex interpolation hack with 3-stop support**

## Performance

- **Duration:** ~15 min (3 commits across debugging session)
- **Started:** 2026-02-01T18:10:00Z
- **Completed:** 2026-02-01T18:30:00Z
- **Tasks:** 2 (1 implementation, 1 visual verification)
- **Files modified:** 3

## Accomplishments
- draw_gradient_rect() now uses gradient_pip instead of rounded_rect_pip
- Gradient stops packed into tm matrix via sgl.matrix_mode_texture()
- Fragment shader performs smooth color interpolation with dithering
- Premultiplied alpha prevents gray artifacts on transparent gradients
- Both Metal (macOS) and GLSL (Linux) backends produce correct output

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire draw_gradient_rect to gradient pipeline** - `962ef0b` (feat)
   - Follow-up fix: `7f90ede` (slice syntax for sgl.mult_matrix)
   - Follow-up fix: `113aa6d` (pass stop data via varyings instead of FS uniforms)

2. **Task 2: Visual verification** - Human checkpoint (APPROVED)

## Files Created/Modified
- `render.v` - draw_gradient_rect uses gradient_pip, packs stops into tm matrix
- `shaders_glsl.v` - Vertex shader reads tm and passes stop data via varyings
- `shaders_metal.v` - Same varying-based approach for Metal backend

## Decisions Made

**Varying-based stop data:** Original approach used fragment shader uniform reads from tm matrix.
This caused issues with uniform access timing. Changed to vertex shader reading tm and passing
stop0/stop1/stop2 as varyings to fragment shader. Reliable and hardware-interpolated.

**Slice syntax for sgl.mult_matrix:** V language requires `&tm_data[0..]` syntax for passing array
pointer to C function, not `unsafe { &tm_data[0] }`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed sgl.mult_matrix call syntax**
- **Found during:** Task 1 (initial implementation)
- **Issue:** V compiler rejected `unsafe { &tm_data[0] }` for sgl.mult_matrix
- **Fix:** Changed to `&tm_data[0..]` slice syntax
- **Files modified:** render.v
- **Committed in:** 7f90ede

**2. [Rule 1 - Bug] Fixed shader uniform access for stop data**
- **Found during:** Task 1 (visual verification showed black output)
- **Issue:** Fragment shader reading tm uniform was unreliable/timing-dependent
- **Fix:** Moved tm matrix read to vertex shader, pass stop0/stop1/stop2 as varyings
- **Files modified:** render.v, shaders_glsl.v, shaders_metal.v
- **Committed in:** 113aa6d

---

**Total deviations:** 2 auto-fixed (both bugs)
**Impact on plan:** Both fixes necessary for correct rendering. No scope creep.

## Issues Encountered

- Initial black gradient output traced to fragment shader uniform timing issue
- Resolved by architectural change to varying-based stop data

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Phase 1 Complete:**
- Fragment shader gradient infrastructure fully operational
- draw_gradient_rect uses gradient_pip with multi-stop support
- Dithering and premultiplied alpha working as designed
- Both Metal and GLSL backends verified

**Ready for Phase 2 (Gradient Stops API):**
- Infrastructure supports up to 3 gradient stops
- GradientStop type and gradient.stops array available
- Next phase can expand public API for user-defined multi-stop gradients

**No blockers.** Phase 1 foundation complete.

---
*Phase: 01-fragment-shader-foundation*
*Completed: 2026-02-01*
