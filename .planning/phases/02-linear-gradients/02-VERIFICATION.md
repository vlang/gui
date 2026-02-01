---
phase: 02-linear-gradients
verified: 2026-02-01T23:30:00Z
status: human_needed
score: 4/4 must-haves verified (code structure)
human_verification:
  - test: "Visual gradient direction test"
    expected: "All 8 direction keywords render correctly"
    why_human: "Visual rendering requires running app and observing gradient angles"
---

# Phase 2: Linear Gradients Verification Report

**Phase Goal:** Users can define linear gradients with arbitrary direction/angle matching CSS behavior

**Verified:** 2026-02-01T23:30:00Z

**Status:** human_needed

**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Gradient struct accepts direction enum or explicit angle | ✓ VERIFIED | styles.v:52-53 has direction and angle fields |
| 2 | Direction keywords map to correct CSS angles | ✓ VERIFIED | render.v:827-835 match statement maps all 8 keywords |
| 3 | Corner keywords adjust for element aspect ratio | ✓ VERIFIED | render.v:832-835 use atan2(height, width) |
| 4 | Default direction is to_bottom (180deg) matching CSS | ✓ VERIFIED | styles.v:52 default = .to_bottom |
| 5 | Gradient direction changes visual angle of color transition | ? NEEDS HUMAN | Requires visual verification in running app |
| 6 | to_top shows first color at bottom, last at top | ? NEEDS HUMAN | Requires visual verification in running app |
| 7 | to_right shows first color at left, last at right | ? NEEDS HUMAN | Requires visual verification in running app |
| 8 | 45deg diagonal shows correct angle | ? NEEDS HUMAN | Requires visual verification in running app |
| 9 | Corner keywords point to actual corners regardless of aspect ratio | ? NEEDS HUMAN | Requires visual verification in running app |

**Score:** 4/4 code structure truths verified, 5/9 total truths need human verification

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `styles.v` | Direction enum and Gradient fields | ✓ VERIFIED | Lines 27-36: Direction enum with 8 values. Lines 52-53: direction and angle fields |
| `render.v` | angle_to_direction and gradient_direction functions | ✓ VERIFIED | Lines 811-816: angle_to_direction(). Lines 818-838: gradient_direction() |
| `render.v` | tm[3] packing with direction vector | ✓ VERIFIED | Lines 889-893: dx,dy packed into tm_data[12-13] |
| `shaders_glsl.v` | stop_dir support in VS and FS | ✓ VERIFIED | Line 198: VS output. Line 222: FS input. Line 246: dot(uv, dir) projection |
| `shaders_metal.v` | stop_dir support in VS and FS | ✓ VERIFIED | Line 224: VertexOut field. Line 243: tm[3].xy read. Line 283: dot(uv, dir) projection |

**All artifacts:** 5/5 verified

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| render.v | styles.v | Direction enum | ✓ WIRED | gradient_direction() accesses gradient.direction (line 827) |
| render.v | tm[3] | direction vector packing | ✓ WIRED | tm_data[12] = dx, tm_data[13] = dy (lines 890-891) |
| shaders_glsl.v | tm[3] | direction vector read in VS | ✓ WIRED | stop_dir = tm[3].xy (line 209) |
| shaders_metal.v | tm[3] | direction vector read in VS | ✓ WIRED | out.stop_dir = uniforms.tm[3].xy (line 243) |
| shaders_glsl.v | stop_dir | dot product projection | ✓ WIRED | t = dot(uv, dir) * 0.5 + 0.5 (line 247) |
| shaders_metal.v | stop_dir | dot product projection | ✓ WIRED | t = dot(in.uv, dir) * 0.5 + 0.5 (line 284) |

**All key links:** 6/6 wired

### Requirements Coverage

| Requirement | Status | Blocking Issue |
|-------------|--------|----------------|
| LIN-01: 3+ color stops at arbitrary positions | ✓ SATISFIED | Inherited from Phase 1 (verified) |
| LIN-02: Gradient direction via CSS angles | ✓ SATISFIED | angle field exists, angle_to_direction() implemented, needs visual test |
| LIN-03: Gradient direction via CSS keywords | ✓ SATISFIED | Direction enum exists, all 8 keywords mapped, needs visual test |

**Coverage:** 3/3 requirements have code support. Visual verification needed for LIN-02 and LIN-03.

### Anti-Patterns Found

None. Code is clean with no TODOs, FIXMEs, placeholders, or stub patterns in modified files.

### Human Verification Required

All automated structural checks pass. Visual behavior verification needed:

#### 1. Direction keyword visual verification

**Test:**
1. Run `v run examples/gradient_demo.v`
2. Modify gradient_demo.v to test each direction:
   - .to_top (0deg): first color at bottom, last at top
   - .to_right (90deg): first color at left, last at right
   - .to_bottom (180deg): first color at top, last at bottom (default)
   - .to_left (270deg): first color at right, last at left
   - .to_top_right: diagonal to top-right corner
   - .to_bottom_right: diagonal to bottom-right corner
   - .to_bottom_left: diagonal to bottom-left corner
   - .to_top_left: diagonal to top-left corner

**Expected:**
- Each direction keyword renders gradient in correct visual direction
- Corner keywords point to actual corners regardless of rect aspect ratio

**Why human:** Visual rendering cannot be verified programmatically

#### 2. Explicit angle visual verification

**Test:**
1. Modify gradient_demo.v to use angle field:
   ```v
   gradient: &gui.Gradient{
       stops: [...]
       angle: 45.0  // or 0.0, 90.0, 135.0, 180.0, etc.
   }
   ```
2. Test angles: 0, 45, 90, 135, 180, 225, 270, 315 degrees
3. Verify angle overrides direction keyword when both set

**Expected:**
- 0deg: vertical up (to top)
- 45deg: diagonal to top-right
- 90deg: horizontal right
- 135deg: diagonal to bottom-right
- 180deg: vertical down (to bottom)
- 225deg: diagonal to bottom-left
- 270deg: horizontal left
- 315deg: diagonal to top-left
- Explicit angle always wins when both angle and direction set

**Why human:** Visual angle accuracy requires human observation

#### 3. Aspect ratio adaptation for corner keywords

**Test:**
1. Create gradients with different aspect ratios:
   - Wide rect (400x100) with .to_top_right
   - Tall rect (100x400) with .to_top_right
   - Square (200x200) with .to_top_right
2. Verify gradient line points to actual corner in all cases

**Expected:**
- Corner keywords adapt gradient angle based on element dimensions
- Gradient line always points to specified corner, not fixed 45deg

**Why human:** Aspect ratio visual correctness requires observation

#### 4. CSS spec compliance

**Test:**
Compare v-gui gradient rendering with CSS gradients in browser:
1. Create matching gradients in both v-gui and CSS
2. Screenshot both
3. Verify visual match (angles, color positions, overall appearance)

**Expected:**
- v-gui gradients visually match CSS `linear-gradient()` with same parameters
- CSS: `linear-gradient(to top right, blue, red)` matches v-gui Direction.to_top_right

**Why human:** Cross-platform visual comparison

---

## Summary

**Code structure:** All must-haves verified at all three levels (existence, substantive, wired)

**Visual behavior:** Needs human verification

Phase 2 code implementation is complete and correct. Direction enum, angle field, gradient_direction() computation, and shader projection all exist and are wired correctly. Both GLSL and Metal shaders read direction from tm[3].xy and compute directional t-value using dot product.

**Recommendation:** Conduct human visual verification tests outlined above. If visual tests pass, phase 2 goal is achieved.

---

*Verified: 2026-02-01T23:30:00Z*
*Verifier: Claude (gsd-verifier)*
