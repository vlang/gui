---
phase: 02-linear-gradients
plan: 01
subsystem: rendering
tags: [gradients, css, shaders, v-gui, fragment-shader]

# Dependency graph
requires:
  - phase: 01-fragment-shader-foundation
    provides: tm matrix packing, gradient pipeline, draw_gradient_rect wiring
provides:
  - Direction enum with 8 CSS keywords (to_top, to_right, etc.)
  - Gradient.direction field (default to_bottom)
  - Gradient.angle field (optional explicit angle)
  - gradient_direction() function for vector computation
  - tm[3] packing with direction vector (dx, dy)
affects: [02-02, 02-03, shader-implementation, gradient-rendering]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "CSS angle to math vector conversion (90-degree rotation)"
    - "Corner keywords with atan2 aspect-ratio adjustment"
    - "Optional ?f32 angle overrides direction enum"

key-files:
  created: []
  modified:
    - styles.v
    - render.v

key-decisions:
  - "Direction default is .to_bottom (180deg) matching CSS spec"
  - "angle ?f32 field overrides direction when set"
  - "Corner keywords use atan2 for aspect-ratio-aware angles"
  - "Direction vector packed into tm[3].xy for shader access"

patterns-established:
  - "CSS degrees: 0=top, 90=right, 180=bottom, 270=left (clockwise)"
  - "Math conversion: rad = (90 - css_degrees) * pi/180"
  - "Corner angles: 90 +/- atan2(height, width) * 180/pi"

# Metrics
duration: 1min
completed: 2026-02-01
---

# Phase 02 Plan 01: Direction/Angle Support Summary

**Direction enum with CSS keywords, optional angle field, direction vector computation packed into tm[3]**

## Performance

- **Duration:** 1 min
- **Started:** 2026-02-01T19:28:16Z
- **Completed:** 2026-02-01T19:29:43Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Direction enum with 8 CSS keywords matching CSS spec
- Gradient struct extended with direction (default .to_bottom) and optional angle
- gradient_direction() computes direction vector from angle or keyword
- Corner keywords use atan2 for aspect-ratio-aware angle calculation
- Direction vector (dx, dy) packed into tm[3].xy for shader consumption

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Direction enum and angle field to Gradient struct** - `9e14197` (feat)
2. **Task 2: Compute direction vector and pack into tm[3]** - `2808882` (feat)

## Files Created/Modified
- `styles.v` - Direction enum, Gradient.direction/.angle fields
- `render.v` - angle_to_direction(), gradient_direction(), tm[3] packing

## Decisions Made
- Direction default is .to_bottom (180deg) per CSS spec - ensures backward compatibility
- angle ?f32 field overrides direction keyword when set - explicit control
- Corner keywords use atan2(height, width) for aspect-ratio adjustment - matches CSS behavior
- Direction vector packed into tm[3].xy - shader can read gradient direction

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for shader implementation (02-02):
- Direction vector computed and packed into tm[3]
- Both angle and keyword-based direction supported
- Corner keywords adjust for element aspect ratio
- Default matches CSS spec (to_bottom = 180deg)

Shader needs to:
- Read direction vector from tm[3].xy
- Compute gradient line projection using dot product
- Map fragment position to gradient position

---
*Phase: 02-linear-gradients*
*Completed: 2026-02-01*
