---
phase: 02-linear-gradients
plan: 02
subsystem: rendering
tags: [gradients, shaders, glsl, metal, fragment-shader, v-gui]

# Dependency graph
requires:
  - phase: 02-01
    provides: Direction vector computation and tm[3] packing
provides:
  - GLSL shader directional gradient support
  - Metal shader directional gradient support
  - dot(uv, dir) projection for gradient positioning
  - Directional t-value calculation from direction vector
affects: [02-03, gradient-rendering, visual-verification]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "VS passes direction via varying (stop_dir)"
    - "FS projects UV onto direction vector using dot product"
    - "t = dot(uv, dir) * 0.5 + 0.5 maps -1..1 to 0..1"

key-files:
  created: []
  modified:
    - shaders_glsl.v
    - shaders_metal.v

key-decisions:
  - "Both shaders read direction from tm[3].xy"
  - "Projection via dot(uv, dir) determines gradient position"
  - "Clamp t to [0,1] prevents out-of-range interpolation"

patterns-established:
  - "Shader varying pattern: VS reads uniform, passes to FS"
  - "Direction vector normalization in render.v, projection in shader"
  - "UV space projection: dot product gives signed distance along direction"

# Metrics
duration: 3min
completed: 2026-02-01
---

# Phase 02 Plan 02: Shader Direction Support Summary

**GLSL and Metal shaders project UV onto direction vector via dot product for directional gradient rendering**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-01T19:33:43Z
- **Completed:** 2026-02-01T19:36:24Z
- **Tasks:** 2 (1 auto + 1 checkpoint)
- **Files modified:** 2

## Accomplishments
- GLSL shader reads stop_dir from tm[3].xy, computes directional t via dot product
- Metal shader mirrors GLSL pattern with stop_dir varying
- Both shaders project UV onto direction vector with dot(uv, dir) * 0.5 + 0.5
- Clamp t to [0,1] ensures safe interpolation
- All 8 direction keywords render correctly (to_top, to_right, corners, etc.)
- Explicit angle support verified (45deg diagonals work)

## Task Commits

Each task was committed atomically:

1. **Task 1: Update GLSL and Metal gradient shaders** - `52ece49` (feat)
2. **Task 2: Checkpoint - Visual verification** - approved by user

**Plan metadata:** (pending)

## Files Created/Modified
- `shaders_glsl.v` - VS outputs stop_dir, FS computes t from dot(uv, dir)
- `shaders_metal.v` - Same pattern, stop_dir in VertexOut, FS projection

## Decisions Made
- Both shaders read direction from tm[3].xy - consistent with render.v packing
- Projection via dot(uv, dir) - standard GPU technique for directional gradients
- Clamp t to [0,1] - prevents artifacts from out-of-range interpolation

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for multi-stop support (02-03):
- Direction vector read from tm[3].xy in both backends
- Projection math working correctly for all directions
- Visual verification confirms correct rendering
- Corner keywords adapt to aspect ratio as expected

Next needs:
- Extend shader to handle 4+ stops beyond tm matrix capacity
- Implement 2-pass rendering or stop buffer for large gradients

---
*Phase: 02-linear-gradients*
*Completed: 2026-02-01*
