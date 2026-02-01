# Testing Patterns

**Analysis Date:** 2026-02-01

## Test Framework

**Runner:**
- V's built-in test runner
- Config: No explicit config file (uses V defaults)

**Assertion Library:**
- V's built-in `assert` statement

**Run Commands:**
```bash
v test .                   # Run all tests
v -check-syntax .          # Check syntax without running
```

## Test File Organization

**Location:**
- Co-located in same directory as source code (not in separate test directory)
- Root-level tests in `/Users/mike/Documents/github/gui/`

**Naming:**
- Prefix with underscore: `_<name>_test.v` (e.g., `_event_test.v`,
  `_layout_test.v`, `_bounded_map_test.v`)
- 14 test files in root directory

**Structure:**
```
/Users/mike/Documents/github/gui/
├── _event_test.v          # Event modifier tests
├── _layout_test.v         # Layout calculation tests
├── _integration_test.v    # Multi-component tests
├── _theme_test.v          # Theme system tests
├── _bounded_map_test.v    # Data structure tests
├── _bounded_stack_test.v
├── _layout_border_test.v
├── _render_test.v
├── _shaders_test.v
├── _styles_test.v
├── _test_fixtures.v       # Shared test helpers
├── _test_refactor.v       # Experimental/refactor tests
├── _xtra_math_test.v      # Utility math tests
└── _xtra_text_test.v      # Text processing tests
```

## Test Structure

**Suite Organization:**
```v
module gui

fn test_feature_name() {
  // Setup
  mut component := ComponentType{}

  // Act
  result := component.method()

  // Assert
  assert result == expected_value
}
```

**Patterns:**
- Each test function is standalone (no shared setup/teardown across tests)
- Inline setup: Create test objects directly in function
  ```v
  fn test_layout_parents() {
    mut c1 := Layout{
      shape: &Shape{ uid: 2 }
    }
  ```
- Comments separate Arrange/Act/Assert phases informally
  ```v
  fn test_adjust_font_size_increase_within_bounds() {
    // Arrange
    old_theme := theme()
    cfg := old_theme.cfg
    base := cfg.text_style.size
    // Act
    if t := old_theme.adjust_font_size(2, 1, 200) {
      // Assert
      assert t.cfg.text_style.size == base + 2
    }
  }
  ```

## Mocking

**Framework:** None detected - no mocking framework used

**Patterns:**
- Manual test object creation with sensible defaults
  ```v
  fn make_test_layout(w f32, h f32) Layout {
    return Layout{
      shape: &Shape{
        width: w
        height: h
      }
    }
  }
  ```
- Inline mock creation for simple cases
  ```v
  fn test_rects_overlap() {
    a := make_clip(0, 0, 10, 10)
    b := make_clip(5, 5, 10, 10)
    assert rects_overlap(a, b)
  }
  ```

**What to Mock:**
- Data structures with complex initialization (use builder functions)
- External state accessed via mutable window objects
  ```v
  fn make_window() Window {
    mut w := Window{}
    w.renderers = []
    return w
  }
  ```

**What NOT to Mock:**
- Core logic functions (test behavior directly)
- Value calculations (test against actual values)
- Assertions use direct value checks without proxies

## Fixtures and Factories

**Test Data:**
- Color constants for consistency
  ```v
  const test_red = rgba(255, 0, 0, 255)
  const test_green = rgba(0, 255, 0, 255)
  const test_blue = rgba(0, 0, 255, 255)
  const test_transparent = rgba(0, 0, 0, 0)
  ```
- Theme builders
  ```v
  fn default_test_theme_cfg() ThemeCfg {
    return ThemeCfg{
      name: 'test-theme'
      color_background: white
      color_panel: gray
      color_interior: dark_gray
      text_style: TextStyle{
        size: 16
        color: black
        family: base_font_name
      }
    }
  }
  ```
- Layout builders
  ```v
  fn make_test_layout(w f32, h f32) Layout {
    return Layout{
      shape: &Shape{
        width: w
        height: h
      }
    }
  }
  fn make_test_layout_with_children(w f32, h f32, children []Layout) Layout {
    return Layout{
      shape: &Shape{ width: w, height: h }
      children: children
    }
  }
  ```

**Location:**
- `/Users/mike/Documents/github/gui/_test_fixtures.v` - Centralized fixtures
- Functions exported at module level (no separate fixtures module)
- Shared across all test files that import module `gui`

## Coverage

**Requirements:** No coverage enforcement detected

**View Coverage:**
- No coverage reporting tool configured
- Run tests with: `v test .`

## Test Types

**Unit Tests:**
- Majority of tests (isolated function/method testing)
- Examples: `_event_test.v`, `_bounded_map_test.v`
- Test single functions or small units
- Fast execution with minimal state setup

**Integration Tests:**
- `/Users/mike/Documents/github/gui/_integration_test.v` - Multi-component tests
- Verify theme colors applied to button/input styles
- Test shape scroll ID assignment
- Test modifier combinations across systems
- Larger state setup (themes, shapes with relationships)

**E2E Tests:**
- Not present in codebase
- Visual/interactive testing done via examples (e.g., `examples/buttons.v`)

## Common Patterns

**Floating-Point Testing:**
```v
// Use f32_are_close() for tolerance-based comparisons
fn f32_are_close(a f32, b f32) bool {
  d := if a >= b { a - b } else { b - a }
  return d <= f32_tolerance
}

// In tests:
assert f32_are_close(root.shape.width, 100.0)
assert f32_are_close(root.shape.min_width, 80.0)
```

**Optional/Error Testing:**
```v
// Test success path with option unpacking
if t := old_theme.adjust_font_size(2, 1, 200) {
  assert t.cfg.text_style.size == base + 2
} else {
  assert false, 'adjust_font_size should not error'
}

// Test error path - expect none
if _ := old_theme.adjust_font_size(0, 0, 10) {
  assert false, 'Expected error when min_size < 1'
} else {
  assert true
}
```

**Array/Collection Testing:**
```v
// Test length
assert m.len() == 3

// Test element access
assert m.get('a') or { -1 } == 1

// Test filtering
text_run := rt.runs.filter(it.text == 'Hello')[0] or { panic('no Hello run') }
assert text_run.style.size == t.b1.size

// Test existence
assert m.contains('a') == true
```

**Pattern Matching in Assertions:**
```v
// Test specific type after cast
match r {
  DrawRect {
    assert r.x == s.x
    assert r.y == s.y
    assert r.is_rounded
    assert r.radius == s.radius
  }
  else {
    assert false, 'expected DrawRect'
  }
}
```

**Unsafe Blocks in Tests:**
```v
// Used for bitwise operations on enums
unsafe {
  combined := Modifier(u32(Modifier.ctrl) | u32(Modifier.shift))
  assert combined.has(.ctrl)
  assert combined.has(.shift)
}

// Used for nil pointer checks
assert unsafe { p.parent == nil }
assert unsafe { p.children[0].parent == &p }
```

**Assertion Messages:**
- Many assertions include messages describing what failed
  ```v
  assert combined.has(.ctrl), 'Combined modifier should have ctrl'
  assert combined.has(.shift), 'Combined modifier should have shift'
  ```
- Format: `assert condition, 'human description of what was tested'`

---

*Testing analysis: 2026-02-01*
