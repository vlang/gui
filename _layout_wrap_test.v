module gui

// Test 1: 3 items (30px each), 80px available, 5px spacing.
// Items 1+2 fit (30+5+30=65), item 3 wraps to second row.
fn test_wrap_basic() {
	mut root := Layout{
		shape:    &Shape{
			axis:    .left_to_right
			wrap:    true
			width:   80
			spacing: 5
		}
		children: [
			Layout{
				shape: &Shape{
					width:      30
					shape_type: .rectangle
				}
			},
			Layout{
				shape: &Shape{
					width:      30
					shape_type: .rectangle
				}
			},
			Layout{
				shape: &Shape{
					width:      30
					shape_type: .rectangle
				}
			},
		]
	}

	layout_wrap(mut root)

	// Container axis flipped to TTB
	assert root.shape.axis == .top_to_bottom
	// 2 implicit rows
	assert root.children.len == 2
	// Row 1: items 1+2
	assert root.children[0].children.len == 2
	// Row 2: item 3
	assert root.children[1].children.len == 1
	// Implicit rows are LTR with correct spacing
	assert root.children[0].shape.axis == .left_to_right
	assert root.children[0].shape.spacing == 5
}

// Test 2: All items fit in one row — no restructuring.
fn test_wrap_single_row() {
	mut root := Layout{
		shape:    &Shape{
			axis:    .left_to_right
			wrap:    true
			width:   200
			spacing: 5
		}
		children: [
			Layout{
				shape: &Shape{
					width:      30
					shape_type: .rectangle
				}
			},
			Layout{
				shape: &Shape{
					width:      30
					shape_type: .rectangle
				}
			},
			Layout{
				shape: &Shape{
					width:      30
					shape_type: .rectangle
				}
			},
		]
	}

	layout_wrap(mut root)

	// No restructuring — axis stays LTR, children not nested
	assert root.shape.axis == .left_to_right
	assert root.children.len == 3
}

// Test 3: After wrap + height calc, container height = sum of row heights + spacing.
fn test_wrap_heights() {
	mut root := Layout{
		shape:    &Shape{
			axis:    .left_to_right
			wrap:    true
			width:   80
			spacing: 10
		}
		children: [
			Layout{
				shape: &Shape{
					width:      30
					height:     20
					shape_type: .rectangle
				}
			},
			Layout{
				shape: &Shape{
					width:      30
					height:     20
					shape_type: .rectangle
				}
			},
			Layout{
				shape: &Shape{
					width:      30
					height:     25
					shape_type: .rectangle
				}
			},
		]
	}

	layout_wrap(mut root)
	layout_heights(mut root)

	// Row 1 height: max(20, 20) = 20
	// Row 2 height: 25
	// Container: 20 + 25 + spacing 10 = 55
	assert root.children.len == 2
	assert f32_are_close(root.children[0].shape.height, 20)
	assert f32_are_close(root.children[1].shape.height, 25)
	assert f32_are_close(root.shape.height, 55)
}

// Test 4: Full pipeline positioning — second row y = first row height + spacing.
fn test_wrap_positions() {
	mut root := Layout{
		shape:    &Shape{
			axis:    .left_to_right
			wrap:    true
			width:   80
			height:  100
			sizing:  fixed_fixed
			spacing: 5
		}
		children: [
			Layout{
				shape: &Shape{
					width:      30
					height:     20
					shape_type: .rectangle
				}
			},
			Layout{
				shape: &Shape{
					width:      30
					height:     20
					shape_type: .rectangle
				}
			},
			Layout{
				shape: &Shape{
					width:      30
					height:     15
					shape_type: .rectangle
				}
			},
		]
	}

	layout_wrap(mut root)
	layout_heights(mut root)
	layout_fill_heights(mut root)
	mut mock_window := Window{}
	layout_positions(mut root, 0, 0, &mock_window)

	// Row 1 at y=0, row 2 at y=20+5=25
	assert f32_are_close(root.children[0].shape.y, 0)
	assert f32_are_close(root.children[1].shape.y, 25)
	// Items within row 1 positioned horizontally
	assert f32_are_close(root.children[0].children[0].shape.x, 0)
	assert f32_are_close(root.children[0].children[1].shape.x, 35)
}

// Test 5: Float/over_draw children stay in row without affecting line breaks.
fn test_wrap_non_flow() {
	mut root := Layout{
		shape:    &Shape{
			axis:    .left_to_right
			wrap:    true
			width:   80
			spacing: 5
		}
		children: [
			Layout{
				shape: &Shape{
					width:      30
					shape_type: .rectangle
				}
			},
			Layout{
				shape: &Shape{
					width:      10
					shape_type: .rectangle
					float:      true
				}
			},
			Layout{
				shape: &Shape{
					width:      30
					shape_type: .rectangle
				}
			},
			Layout{
				shape: &Shape{
					width:      30
					shape_type: .rectangle
				}
			},
		]
	}

	layout_wrap(mut root)

	// Float child doesn't consume width, so items 1+3 fit (30+5+30=65)
	// Item 4 wraps. Float child stays in row 1.
	assert root.children.len == 2
	// Row 1: item1 + float + item3
	assert root.children[0].children.len == 3
	// Row 2: item4
	assert root.children[1].children.len == 1
}

// Test 6: wrap() convenience function sets axis and wrap flag.
fn test_wrap_convenience() {
	v := wrap(ContainerCfg{})
	mut cv := v as ContainerView
	assert cv.axis == .left_to_right
	assert cv.wrap == true
}
