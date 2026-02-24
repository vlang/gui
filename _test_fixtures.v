module gui

// Test Fixtures and Utilities
//
// This file provides common test helpers, builders, and assertions
// for the GUI test suite. These reduce code duplication across tests.
//

// Test color constants for consistent test data
const test_red = rgba(255, 0, 0, 255)
const test_green = rgba(0, 255, 0, 255)
const test_blue = rgba(0, 0, 255, 255)
const test_transparent = rgba(0, 0, 0, 0)

// Note: f32_are_close is already defined in xtra_math.v
// Use it directly from there for floating-point comparisons in tests.

// test_f32_close_with_tolerance checks if two f32 values are within custom tolerance.
// Use this when you need custom tolerance instead of the default f32_tolerance.
fn test_f32_close_with_tolerance(a f32, b f32, tolerance f32) bool {
	diff := if a > b { a - b } else { b - a }
	return diff <= tolerance
}

// make_test_layout creates a simple layout for testing.
// Provides sensible defaults that can be overridden.
fn make_test_layout(w f32, h f32) Layout {
	return Layout{
		shape: &Shape{
			width:  w
			height: h
		}
	}
}

// make_test_layout_with_children creates a parent layout with the given children.
fn make_test_layout_with_children(w f32, h f32, children []Layout) Layout {
	return Layout{
		shape:    &Shape{
			width:  w
			height: h
		}
		children: children
	}
}

// make_test_shape creates a Shape with common defaults for testing.
fn make_test_shape() &Shape {
	return &Shape{
		width:   100
		height:  100
		radius:  5
		color:   test_red
		padding: Padding{}
	}
}

// default_test_theme_cfg returns a ThemeCfg with test-friendly defaults.
fn default_test_theme_cfg() ThemeCfg {
	return ThemeCfg{
		name:             'test-theme'
		color_background: white
		color_panel:      gray
		color_interior:   dark_gray
		text_style:       TextStyle{
			size:   16
			color:  black
			family: base_font_name
		}
	}
}

// make_test_theme creates a theme from the default test configuration.
fn make_test_theme() Theme {
	cfg := default_test_theme_cfg()
	return theme_maker(&cfg)
}

// assert_color_eq is a helper for comparing colors with clear error messages.
// Returns true if colors are equal, false otherwise.
fn assert_color_eq(actual Color, expected Color) bool {
	if actual.r != expected.r || actual.g != expected.g || actual.b != expected.b
		|| actual.a != expected.a {
		return false
	}
	return true
}

// build_deep_layout creates a Layout tree of given depth and fanout
// for memory/GC tests. Leaf nodes are 10x10, interior nodes 100x100.
fn build_deep_layout(depth int, fanout int) Layout {
	if depth == 0 {
		return make_test_layout(10, 10)
	}
	mut children := []Layout{cap: fanout}
	for _ in 0 .. fanout {
		children << build_deep_layout(depth - 1, fanout)
	}
	return make_test_layout_with_children(100, 100, children)
}

// assert_layout_dimensions checks if a layout has expected dimensions.
fn assert_layout_dimensions(layout &Layout, expected_w f32, expected_h f32) bool {
	return f32_are_close(layout.shape.width, expected_w)
		&& f32_are_close(layout.shape.height, expected_h)
}
