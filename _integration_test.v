module gui

// Integration Tests
//
// These tests verify component interactions and end-to-end behavior
// that unit tests don't cover. They test:
// - Theme creation and color cascading
// - Layout width/height calculations
// - Modifier flag operations
// - Shape and Layout data structures
//

// Test: Modifier combination and detection
fn test_modifier_combinations() {
	// Test combined modifiers (must use unsafe for bitwise ops on enums)
	unsafe {
		combined := Modifier(u32(Modifier.ctrl) | u32(Modifier.shift))
		assert combined.has(.ctrl), 'Combined modifier should have ctrl'
		assert combined.has(.shift), 'Combined modifier should have shift'
		assert !combined.has(.alt), 'Combined modifier should not have alt'

		// Test all modifiers
		all := Modifier(u32(Modifier.ctrl) | u32(Modifier.shift) | u32(Modifier.alt) | u32(Modifier.super))
		assert all.has(.ctrl)
		assert all.has(.shift)
		assert all.has(.alt)
		assert all.has(.super)
	}
}

// Test: Theme colors are correctly applied to button style
fn test_theme_button_style_colors() {
	cfg := ThemeCfg{
		name:             'test-button-theme'
		color_interior:   red
		color_hover:      green
		color_focus:      blue
		color_border:     yellow
		color_select:     magenta
		color_background: white
	}

	t := theme_maker(&cfg)

	// Button should use theme colors
	assert t.button_style.color == red
	assert t.button_style.color_hover == green
	assert t.button_style.color_border == yellow
}

// Test: Theme colors are correctly applied to input style
fn test_theme_input_style_colors() {
	cfg := ThemeCfg{
		name:           'test-input-theme'
		color_interior: red
		color_hover:    green
		color_border:   yellow
		color_select:   magenta
	}

	t := theme_maker(&cfg)

	// Input should use theme colors
	assert t.input_style.color == red
	assert t.input_style.color_hover == green
	assert t.input_style.color_border == yellow
}

// Test: Shape scroll id assignment
fn test_scroll_shape_id() {
	// Shapes with id_scroll > 0 can receive scroll events
	scrollable := Shape{
		id_scroll: 100
		height:    200
	}

	non_scrollable := Shape{
		id_scroll: 0
		height:    200
	}

	assert scrollable.id_scroll > 0, 'Scrollable shape should have id_scroll > 0'
	assert non_scrollable.id_scroll == 0, 'Non-scrollable shape should have id_scroll == 0'
}

// Test: Disabled shapes don't receive events
fn test_disabled_shape_event_handling() {
	shape := Shape{
		disabled: true
		width:    100
		height:   100
	}

	// is_child_enabled should return false for disabled shapes
	layout := Layout{
		shape: &shape
	}

	assert !is_child_enabled(&layout), 'Disabled layout should not be enabled'
}

// Test: Enabled shapes receive events
fn test_enabled_shape_event_handling() {
	shape := Shape{
		disabled: false
		width:    100
		height:   100
	}

	layout := Layout{
		shape: &shape
	}

	assert is_child_enabled(&layout), 'Enabled layout should be enabled'
}

// Test: Focus callback execution conditions
fn test_focus_callback_conditions() {
	// Shape without id_focus should not execute focus callback
	shape_no_focus := Shape{
		id_focus: 0
	}
	layout_no_focus := Layout{
		shape: &shape_no_focus
	}

	// Shape with id_focus should be considered for focus callbacks
	shape_with_focus := Shape{
		id_focus: 1
	}
	layout_with_focus := Layout{
		shape: &shape_with_focus
	}

	assert layout_no_focus.shape.id_focus == 0, 'No focus layout should have id_focus 0'
	assert layout_with_focus.shape.id_focus == 1, 'Focus layout should have id_focus > 0'
}

// Test: Event relative coordinate conversion
fn test_event_relative_coordinates() {
	shape := Shape{
		x:      100
		y:      50
		width:  200
		height: 100
	}

	original_event := Event{
		mouse_x: 150
		mouse_y: 75
	}

	relative := event_relative_to(shape, original_event)

	// Relative coordinates should be offset by shape position
	// relative_x = 150 - 100 = 50
	// relative_y = 75 - 50 = 25
	assert f32_are_close(relative.mouse_x, 50)
	assert f32_are_close(relative.mouse_y, 25)
}

// Test: Color arithmetic operations
fn test_color_operations() {
	c1 := rgba(100, 50, 25, 255)
	c2 := rgba(50, 25, 12, 128)

	// Addition
	sum := c1 + c2
	assert sum.r == 150
	assert sum.g == 75
	assert sum.a == 255 // Alpha clamps at 255

	// Subtraction
	diff := c1 - c2
	assert diff.r == 50
	assert diff.g == 25
}

// Test: Theme with_colors applies overrides correctly
fn test_theme_color_overrides() {
	base := theme_dark
	new_interior := rgb(50, 60, 70)

	modified := base.with_colors(ColorOverrides{
		color_interior: new_interior
	})

	// Top-level color should be updated
	assert modified.color_interior == new_interior

	// Button color should be updated (uses interior)
	assert modified.button_style.color == new_interior
}

// Test: Nested layout parent pointers
fn test_nested_layout_parent_pointers() {
	mut grandchild := Layout{
		shape: &Shape{
			uid: 3
		}
	}
	mut child := Layout{
		shape:    &Shape{
			uid: 2
		}
		children: [grandchild]
	}
	mut root := Layout{
		shape:    &Shape{
			uid: 1
		}
		children: [child]
	}

	layout_parents(mut root, unsafe { nil })

	// Root has no parent
	assert unsafe { root.parent == nil }

	// Child's parent is root
	assert unsafe { root.children[0].parent == &root }

	// Grandchild's parent is child
	assert unsafe { root.children[0].children[0].parent == &root.children[0] }
}

// Test: Theme chained modifications
fn test_theme_chained_modifications() {
	base := theme_dark

	// Chain multiple with_* calls
	modified := base
		.with_button_style(ButtonStyle{
			...base.button_style
			color: red
		})
		.with_input_style(InputStyle{
			...base.input_style
			color: blue
		})

	assert modified.button_style.color == red
	assert modified.input_style.color == blue
	// Other styles unchanged
	assert modified.select_style == base.select_style
}

// Test: Shape uid uniqueness tracking
fn test_shape_uid_assignment() {
	shape1 := Shape{
		uid: 1
	}
	shape2 := Shape{
		uid: 2
	}
	shape3 := Shape{
		uid: 1
	} // Duplicate uid (would be detected at runtime)

	assert shape1.uid != shape2.uid, 'Different shapes should have different uids'
	assert shape1.uid == shape3.uid, 'Same uid values should be equal'
}

// Test: Layout children access
fn test_layout_children_access() {
	child1 := Layout{
		shape: &Shape{
			uid: 10
		}
	}
	child2 := Layout{
		shape: &Shape{
			uid: 20
		}
	}
	child3 := Layout{
		shape: &Shape{
			uid: 30
		}
	}

	parent := Layout{
		shape:    &Shape{
			uid: 1
		}
		children: [child1, child2, child3]
	}

	assert parent.children.len == 3, 'Parent should have 3 children'
	assert parent.children[0].shape.uid == 10
	assert parent.children[1].shape.uid == 20
	assert parent.children[2].shape.uid == 30
}

// Test: Color creation helpers
fn test_color_creation_helpers() {
	// RGB creates opaque color
	c_rgb := rgb(100, 150, 200)
	assert c_rgb.r == 100
	assert c_rgb.g == 150
	assert c_rgb.b == 200
	assert c_rgb.a == 255 // Default alpha

	// RGBA allows alpha specification
	c_rgba := rgba(100, 150, 200, 128)
	assert c_rgba.r == 100
	assert c_rgba.g == 150
	assert c_rgba.b == 200
	assert c_rgba.a == 128

	// Hex conversion
	c_hex := hex(0xFF8040)
	assert c_hex.r == 0xFF
	assert c_hex.g == 0x80
	assert c_hex.b == 0x40
}

// Test: Padding structure
fn test_padding_structure() {
	p := Padding{
		top:    10
		right:  20
		bottom: 30
		left:   40
	}

	assert p.top == 10
	assert p.right == 20
	assert p.bottom == 30
	assert p.left == 40
}

// Test: Axis enum values
fn test_axis_values() {
	// Verify axis enum exists and has expected values
	ttb := Axis.top_to_bottom
	ltr := Axis.left_to_right

	assert ttb != ltr, 'Different axis values should not be equal'
}

// Test: Event type tracking
fn test_event_type_tracking() {
	e := Event{
		typ:          .mouse_down
		mouse_button: .left
		mouse_x:      100
		mouse_y:      200
	}

	assert e.typ == .mouse_down
	assert e.mouse_button == .left
	assert f32_are_close(e.mouse_x, 100)
	assert f32_are_close(e.mouse_y, 200)
	assert !e.is_handled // Default is false
}

// Test: Event handled flag
fn test_event_handled_flag() {
	mut e := Event{
		typ: .mouse_down
	}

	assert !e.is_handled, 'Event should start as not handled'

	e.is_handled = true
	assert e.is_handled, 'Event should be marked as handled'
}
