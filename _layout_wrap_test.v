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

	layout_wrap_containers(mut root)

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

	layout_wrap_containers(mut root)

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

	layout_wrap_containers(mut root)
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

	layout_wrap_containers(mut root)
	layout_heights(mut root)
	layout_fill_heights(mut root)
	mut mock_window := Window{}
	layout_positions(mut root, 0, 0, mut mock_window)

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

	layout_wrap_containers(mut root)

	// Float child doesn't consume width, so items 1+3 fit (30+5+30=65)
	// Item 4 wraps. Float child stays in row 1.
	assert root.children.len == 2
	// Row 1: item1 + float + item3
	assert root.children[0].children.len == 3
	// Row 2: item4
	assert root.children[1].children.len == 1
}

// Test 6: fill-width wrap inside a column — simulates showcase embed.
// The wrap container has fill sizing (width resolved by parent column).
fn test_wrap_fill_in_column() {
	mut root := Layout{
		shape:    &Shape{
			axis:       .top_to_bottom
			width:      400
			height:     300
			sizing:     fixed_fixed
			shape_type: .rectangle
		}
		children: [
			Layout{
				shape:    &Shape{
					axis:       .left_to_right
					wrap:       true
					sizing:     fill_fit
					spacing:    5
					shape_type: .rectangle
				}
				children: [
					Layout{
						shape: &Shape{
							width:      80
							height:     20
							shape_type: .rectangle
						}
					},
					Layout{
						shape: &Shape{
							width:      80
							height:     20
							shape_type: .rectangle
						}
					},
					Layout{
						shape: &Shape{
							width:      80
							height:     20
							shape_type: .rectangle
						}
					},
					Layout{
						shape: &Shape{
							width:      80
							height:     20
							shape_type: .rectangle
						}
					},
					Layout{
						shape: &Shape{
							width:      80
							height:     20
							shape_type: .rectangle
						}
					},
					Layout{
						shape: &Shape{
							width:      80
							height:     20
							shape_type: .rectangle
						}
					},
				]
			},
		]
	}

	// Run the same pipeline steps as layout_pipeline:
	// 1-2: widths + fill_widths → resolve the wrap's width from parent
	layout_widths(mut root)
	layout_fill_widths(mut root)

	// Wrap should now have parent width (400)
	wrap_layout := root.children[0]
	assert f32_are_close(wrap_layout.shape.width, 400), 'wrap width should be 400, got ${wrap_layout.shape.width}'

	// 2.5: wrap pass
	layout_wrap_containers(mut root)

	// 6 items × 80 + 5 spacing = 500 > 400 available, must produce 2+ rows
	assert root.children[0].shape.axis == .top_to_bottom, 'wrap axis should flip to TTB'
	assert root.children[0].children.len >= 2, 'expected 2+ rows, got ${root.children[0].children.len}'
}

// Test 7: wrap() convenience function sets axis and wrap flag.
fn test_wrap_convenience() {
	v := wrap(ContainerCfg{})
	mut cv := v as ContainerView
	assert cv.axis == .left_to_right
	assert cv.wrap == true
}
