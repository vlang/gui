# Phase 2: Linear Gradients - Context

**Gathered:** 2026-02-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Multi-stop linear gradients with user-specified direction control via degrees or CSS keywords. Users can
define gradient angle and direction matching CSS linear-gradient behavior. Radial gradients and repeating
gradients are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Angle specification
- 0° = to top (gradient flows upward), following CSS linear-gradient spec
- Angles rotate clockwise: 90° = to right, 180° = to bottom, 270° = to left
- CSS standard convention throughout

### Direction keywords
- Support all 8 CSS direction keywords: cardinal (to_top, to_bottom, to_left, to_right) plus diagonal
  (to_top_left, to_top_right, to_bottom_left, to_bottom_right)
- Represent as V enum values for type safety and IDE autocomplete
- Diagonal keywords adjust for element aspect ratio (CSS behavior): to_bottom_right points to actual
  corner regardless of shape

### API behavior
- Default direction: to_bottom (180°) matching CSS default
- Smart defaults: minimal code for common cases, sensible fallbacks

### Coordinate system
- Gradient line extends beyond element bounds to cover corners (CSS behavior)
- No visible repetition or edge color clamping
- Repeating gradients explicitly out of scope for this phase

### Claude's Discretion
- Angle normalization strategy (0-360 vs allow any value)
- Angle parameter data type (f32 vs enum wrapper)
- Priority when both angle and keyword specified (suggest error or keyword-wins)
- API integration pattern (extend existing struct vs new LinearGradient type)
- Whether direction is per-call param or pre-configured
- Y-axis convention (match v-gui's existing coord system)
- Shader position calculation (normalized 0-1 consistent with Phase 1)

</decisions>

<specifics>
## Specific Ideas

- CSS compatibility is the reference: when in doubt, match CSS linear-gradient behavior
- Should feel native to V developers while being familiar to web developers

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-linear-gradients*
*Context gathered: 2026-02-01*
