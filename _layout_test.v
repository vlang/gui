module gui

// Test 1: Verifies parent pointers are correctly established in the tree.
fn test_layout_parents() {
	mut c1 := Layout{
		shape: &Shape{
			uid: 2
		}
	}
	mut c2 := Layout{
		shape: &Shape{
			uid: 3
		}
	}
	mut p := Layout{
		shape:    &Shape{
			uid: 1
		}
		children: [c1, c2]
	}

	layout_parents(mut p, unsafe { nil })

	assert unsafe { p.parent == nil }
	assert unsafe { p.children[0].parent == &p }
	assert unsafe { p.children[1].parent == &p }
}

// Test 2: Horizontal layout (.left_to_right) size calculation (bottom-up)
fn test_layout_widths_ltr() {
	// Root is the container with axis LTR
	mut root := Layout{
		shape:    &Shape{
			axis:        .left_to_right
			padding:     Padding{
				left:   10
				right:  10
				top:    0
				bottom: 0
			}
			spacing:     5
			width:       0 // Will be calculated
			size_border: 0
		}
		children: [
			Layout{
				shape: &Shape{
					width:     50
					min_width: 40
				}
			}, // Child 1
			Layout{
				shape: &Shape{
					width:     30
					min_width: 20
				}
			}, // Child 2
		]
	}

	layout_widths(mut root)

	// Expected Width: Child1(50) + Child2(30) + Spacing(5) * 2 + Padding(10+10) = 95
	// Expected Min Width: Child1.min(40) + Child2.min(20) + Spacing(5) * 2 + Padding(10+10) = 75
	assert f32_are_close(root.shape.width, 100.0)
	assert f32_are_close(root.shape.min_width, 80.0)
}

// Test 3: Vertical layout (.top_to_bottom) width calculation (across-axis, max child width)
fn test_layout_widths_ttb() {
	// Root is the container with axis TTB
	mut root := Layout{
		shape:    &Shape{
			axis:        .top_to_bottom
			padding:     Padding{
				left:   5
				right:  5
				top:    0
				bottom: 0
			}
			spacing:     0
			width:       0 // Will be calculated
			size_border: 0
		}
		children: [
			Layout{
				shape: &Shape{
					width:     100
					min_width: 80
				}
			}, // Child 1
			Layout{
				shape: &Shape{
					width:     120
					min_width: 100
				}
			}, // Child 2 (Widest)
			Layout{
				shape: &Shape{
					width:     90
					min_width: 70
				}
			}, // Child 3
		]
	}

	layout_widths(mut root)

	// Expected Width: Max Child Width (120) + Padding(5+5) = 130
	// Expected Min Width: Max Child Min Width (100) + Padding(5+5) = 110
	assert f32_are_close(root.shape.width, 130.0)
	assert f32_are_close(root.shape.min_width, 110.0)
}

// Test 4: Fill width calculation (top-down refinement - GROW)
fn test_layout_fill_widths_ltr_grow() {
	// Fixed container width: 100.
	// Required space: C1(20) + C2(fill, fill) + C3(fill, fill) + Spacing(5) * 2 + Padding(0) = 30
	// Remaining fill space: 100 - 30 = 70. Divided among 2 fill children.
	// C2 and C3 should each get 70 / 2 = 30
	mut root := Layout{
		shape:    &Shape{
			axis:        .left_to_right
			shape_type:  .rectangle
			sizing:      fixed_fixed // Fixed size of 100
			width:       100
			height:      100
			spacing:     5
			size_border: 0
		}
		children: [
			Layout{
				shape: &Shape{
					shape_type: .rectangle
					width:      20
					sizing:     fixed_fill
				}
			}, // C1: Fixed 20
			Layout{
				shape: &Shape{
					shape_type: .rectangle
					width:      0
					height:     100
					sizing:     fill_fill
				}
			}, // C2: Fill, min 10
			Layout{
				shape: &Shape{
					shape_type: .rectangle
					width:      0
					min_width:  10
					sizing:     fill_fill
				}
			}, // C3: Fill, min 10
		]
	}

	// 1. Calculate base widths (bottom-up)
	layout_widths(mut root)
	// At this point, C2/C3 width is 0, root width is 30 (20 + 0 + 0 + 5 + 5)

	// 2. Refine widths (top-down)
	layout_fill_widths(mut root)

	// Expected: 2 fill elements share 70 remaining units. 35 each.
	assert f32_are_close(root.children[1].shape.width, 35) // C2
	assert f32_are_close(root.children[2].shape.width, 35) // C3
}

// Test 5: Fill height calculation (top-down refinement - GROW)
fn test_layout_fill_heights_ttb_grow() {
	// Fixed container height: 100.
	// Required space: C1(20) + C2(0, fill) + C3(0, fill) + Spacing(5) + Padding(0) = 25
	// Remaining fill space: 100 - 25 = 75. Divided among 2 fill children.
	mut root := Layout{
		shape:    &Shape{
			axis:        .top_to_bottom
			sizing:      fixed_fixed // Fixed size of 100
			width:       100
			height:      100
			spacing:     5
			size_border: 0
		}
		children: [
			Layout{
				shape: &Shape{
					shape_type: .rectangle
					height:     20
					sizing:     fill_fixed
				}
			}, // C1: Fixed 20
			Layout{
				shape: &Shape{
					shape_type: .rectangle
					height:     0
					min_height: 10
					sizing:     fill_fill
				}
			}, // C2: Fill, min 10
			Layout{
				shape: &Shape{
					shape_type: .rectangle
					height:     0
					min_height: 10
					sizing:     fill_fill
				}
			}, // C3: Fill, min 10
		]
	}

	// 1. Calculate base heights (bottom-up)
	layout_heights(mut root)
	// At this point, C2/C3 height is 0, root height is 25 (20 + 0 + 0 + 5)

	// 2. Refine heights (top-down)
	layout_fill_heights(mut root)

	// Expected: 2 fill elements share 75 remaining units. 37.5 each.
	assert f32_are_close(root.children[1].shape.height, 35) // C2
	assert f32_are_close(root.children[2].shape.height, 35) // C3
}

// Test 6: Positioning with Center Alignment
fn test_layout_positions_center() {
	// Setup:
	// Root Container (Axis: LTR, Size: 100x100, H-Align: Center, V-Align: Middle, Padding: 10)
	// Child 1 (Size: 40x40)
	// Total space along axis (width): 40 (C1) + 20 (Padding) = 60
	// Remaining horizontal space: 100 - 60 = 40. Center alignment adds 40/2 = 20 margin.
	// Total space across axis (height): 40 (C1) + 20 (Padding) = 60
	// Remaining vertical space: 100 - 60 = 40. Middle alignment adds 40/2 = 20 margin.

	mut root := Layout{
		shape:    &Shape{
			x:           0
			y:           0
			width:       100
			height:      100
			axis:        .left_to_right
			h_align:     .center
			v_align:     .middle
			padding:     Padding{
				left:   10
				right:  10
				top:    10
				bottom: 10
			}
			size_border: 0
			spacing:     5 // only one child so spacing is not used in calcs
		}
		children: [
			Layout{
				shape: &Shape{
					shape_type: .rectangle
					width:      40
					height:     40
				}
			}, // C1
		]
	}

	// Mock window and ensure children have parent set (position relies on it)
	mut mock_window := Window{}
	layout_parents(mut root, unsafe { nil })

	// Run positioning
	layout_positions(mut root, 0, 0, mut mock_window)

	// Root Position (Should be 0, 0 as offsets are 0)
	assert f32_are_close(root.shape.x, 0.0)
	assert f32_are_close(root.shape.y, 0.0)

	// Child 1 Expected Position:
	// X: Root.x (0) + Pad.left (10) + H-Align margin (20) = 30
	// Y: Root.y (0) + Pad.top (10) + V-Align margin (20) = 30.0
	c1_x := root.children[0].shape.x
	c1_y := root.children[0].shape.y

	assert f32_are_close(c1_x, 30)
	assert f32_are_close(c1_y, 30.0)
}

// Test 7: Clipping (layout_set_shape_clips)
fn test_layout_set_shape_clips() {
	// Root clip: (10, 10, 80, 80)
	// Child size: (20, 20, 50, 50) - positioned inside root
	mut root := Layout{
		shape:    &Shape{
			x:      10
			y:      10
			width:  80
			height: 80
		}
		children: [
			Layout{
				shape: &Shape{
					x:      20
					y:      20
					width:  50
					height: 50
				}
			}, // Fully inside
			Layout{
				shape: &Shape{
					x:      70
					y:      70
					width:  50
					height: 50
				}
			}, // Partially clipped (bottom/right)
			Layout{
				shape: &Shape{
					x:      100
					y:      100
					width:  10
					height: 10
				}
			}, // Fully clipped (outside)
		]
	}

	// Initial clip is the full window, assumed to be larger than root
	initial_clip := DrawClip{
		x:      0
		y:      0
		width:  1000
		height: 1000
	}

	layout_set_shape_clips(mut root, initial_clip)

	// Root clip: Intersection of (10,10,80,80) and (0,0,1000,1000) = (10, 10, 80, 80)
	root_clip := root.shape.shape_clip
	assert f32_are_close(root_clip.x, 10.0)
	assert f32_are_close(root_clip.width, 80.0)

	// Child 1 clip: Intersection of (20,20,50,50) and Root Clip (10,10,80,80) = (20, 20, 50, 50)
	c1_clip := root.children[0].shape.shape_clip
	assert f32_are_close(c1_clip.x, 20.0)
	assert f32_are_close(c1_clip.width, 50.0)

	// Child 2 clip: Intersection of (70,70,50,50) and Root Clip (10,10,80,80)
	// Max X: min(70+50=120, 10+80=90) = 90. X: max(70, 10) = 70. Width: 90 - 70 = 20
	// Max Y: min(70+50=120, 10+80=90) = 90. Y: max(70, 10) = 70. Height: 90 - 70 = 20
	c2_clip := root.children[1].shape.shape_clip
	assert f32_are_close(c2_clip.x, 70.0)
	assert f32_are_close(c2_clip.width, 20.0) // Clipped from 50 down to 20

	// Child 3 clip: Intersection of (100,100,10,10) and Root Clip (10,10,80,80)
	// This would result in a width/height <= 0, which the `rect_intersection` mock should handle.
	// In the real implementation, the error is handled, but here we just check the resulting default `DrawClip{}`
	c3_clip := root.children[2].shape.shape_clip
	assert f32_are_close(c3_clip.width, 0.0)
}

fn test_layout_remove_floating_layouts_distinct_placeholders() {
	mut root := Layout{
		shape:    &Shape{
			axis: .left_to_right
		}
		children: [
			Layout{
				shape: &Shape{
					shape_type: .rectangle
					float:      true
				}
			},
			Layout{
				shape: &Shape{
					shape_type: .rectangle
					float:      true
				}
			},
		]
	}
	mut floating := []&Layout{}
	layout_remove_floating_layouts(mut root, mut floating)
	assert floating.len == 2
	assert root.children[0].shape.shape_type == .none
	assert root.children[1].shape.shape_type == .none
	assert unsafe { root.children[0].shape != root.children[1].shape }
}

fn test_layout_scroll_containers_nearest_scroll_parent() {
	mut root := Layout{
		shape:    &Shape{
			shape_type: .rectangle
		}
		children: [
			Layout{
				shape:    &Shape{
					shape_type: .rectangle
					id_scroll:  10
				}
				children: [
					Layout{
						shape: &Shape{
							shape_type: .text
						}
					},
					Layout{
						shape:    &Shape{
							shape_type: .rectangle
							id_scroll:  20
						}
						children: [
							Layout{
								shape: &Shape{
									shape_type: .text
								}
							},
						]
					},
				]
			},
		]
	}
	layout_scroll_containers(mut root, 0)
	assert root.children[0].children[0].shape.id_scroll_container == 10
	assert root.children[0].children[1].children[0].shape.id_scroll_container == 20
}

fn test_layout_fill_widths_root_scroll_fill_no_parent() {
	mut root := Layout{
		shape: &Shape{
			shape_type:  .rectangle
			axis:        .top_to_bottom
			id_scroll:   1
			sizing:      fill_fill
			width:       120
			height:      40
			size_border: 0
		}
	}
	layout_fill_widths(mut root)
	assert f32_are_close(root.shape.width, 120.0)
}

fn test_layout_fill_heights_root_scroll_fill_no_parent() {
	mut root := Layout{
		shape: &Shape{
			shape_type:  .rectangle
			axis:        .left_to_right
			id_scroll:   1
			sizing:      fill_fill
			width:       40
			height:      120
			size_border: 0
		}
	}
	layout_fill_heights(mut root)
	assert f32_are_close(root.shape.height, 120.0)
}

fn test_layout_fill_widths_scroll_child_no_roundoff_bias() {
	mut root := Layout{
		shape:    &Shape{
			shape_type:  .rectangle
			axis:        .left_to_right
			sizing:      fixed_fixed
			width:       100
			height:      50
			padding:     Padding{
				left:   4
				right:  6
				top:    0
				bottom: 0
			}
			spacing:     8
			size_border: 0
		}
		children: [
			Layout{
				shape: &Shape{
					shape_type: .rectangle
					axis:       .none
					sizing:     fixed_fill
					width:      30
					height:     20
				}
			},
			Layout{
				shape: &Shape{
					shape_type: .rectangle
					axis:       .top_to_bottom
					sizing:     fill_fill
					id_scroll:  11
					width:      0
					height:     20
				}
			},
		]
	}
	layout_parents(mut root, unsafe { nil })
	layout_fill_widths(mut root)
	assert f32_are_close(root.children[1].shape.width, 52.0)
}

fn test_layout_fill_heights_scroll_child_no_roundoff_bias() {
	mut root := Layout{
		shape:    &Shape{
			shape_type:  .rectangle
			axis:        .top_to_bottom
			sizing:      fixed_fixed
			width:       50
			height:      100
			padding:     Padding{
				left:   0
				right:  0
				top:    4
				bottom: 6
			}
			spacing:     8
			size_border: 0
		}
		children: [
			Layout{
				shape: &Shape{
					shape_type: .rectangle
					axis:       .none
					sizing:     fill_fixed
					width:      20
					height:     30
				}
			},
			Layout{
				shape: &Shape{
					shape_type: .rectangle
					axis:       .left_to_right
					sizing:     fill_fill
					id_scroll:  12
					width:      20
					height:     0
				}
			},
		]
	}
	layout_parents(mut root, unsafe { nil })
	layout_fill_heights(mut root)
	assert f32_are_close(root.children[1].shape.height, 52.0)
}

// Test: RTL row positions children right-to-left
fn test_layout_positions_rtl_row() {
	mut root := Layout{
		shape:    &Shape{
			x:           0
			y:           0
			width:       200
			height:      50
			axis:        .left_to_right
			text_dir:    .rtl
			padding:     Padding{
				left:   10
				right:  10
				top:    0
				bottom: 0
			}
			size_border: 0
			spacing:     5
		}
		children: [
			Layout{
				shape: &Shape{
					shape_type: .rectangle
					width:      40
					height:     50
				}
			},
			Layout{
				shape: &Shape{
					shape_type: .rectangle
					width:      60
					height:     50
				}
			},
		]
	}

	mut mock_window := Window{}
	layout_parents(mut root, unsafe { nil })
	layout_positions(mut root, 0, 0, mut mock_window)

	// RTL: first child at right edge minus padding
	// x starts at 0 + 200 - 10 (padding_right) = 190
	// Child 0: x = 190 - 40 = 150
	assert f32_are_close(root.children[0].shape.x, 150.0)
	// Child 1: x = 150 - 5 (spacing) - 60 = 85
	assert f32_are_close(root.children[1].shape.x, 85.0)
}

// Test: .start resolves to .right under RTL
fn test_layout_positions_rtl_start_align() {
	// RTL column with h_align .start → resolves to .right
	// Single child 40px wide in 200px container
	mut root := Layout{
		shape:    &Shape{
			x:           0
			y:           0
			width:       200
			height:      100
			axis:        .top_to_bottom
			text_dir:    .rtl
			h_align:     .start
			size_border: 0
			spacing:     0
		}
		children: [
			Layout{
				shape: &Shape{
					shape_type: .rectangle
					width:      40
					height:     30
				}
			},
		]
	}

	mut mock_window := Window{}
	layout_parents(mut root, unsafe { nil })
	layout_positions(mut root, 0, 0, mut mock_window)

	// .start in RTL resolves to .right → child pushed to right edge
	// x_align = 200 - 40 - 0 (padding) = 160
	assert f32_are_close(root.children[0].shape.x, 160.0)
}

// Test: per-container .ltr override in RTL global
fn test_layout_positions_rtl_override_ltr() {
	// Global is RTL but container overrides to LTR
	old_locale := gui_locale
	gui_locale = Locale{
		text_dir: .rtl
	}
	defer {
		gui_locale = old_locale
	}

	mut root := Layout{
		shape:    &Shape{
			x:           0
			y:           0
			width:       200
			height:      50
			axis:        .left_to_right
			text_dir:    .ltr // explicit override
			padding:     Padding{
				left:   10
				right:  10
				top:    0
				bottom: 0
			}
			size_border: 0
			spacing:     5
		}
		children: [
			Layout{
				shape: &Shape{
					shape_type: .rectangle
					width:      40
					height:     50
				}
			},
			Layout{
				shape: &Shape{
					shape_type: .rectangle
					width:      60
					height:     50
				}
			},
		]
	}

	mut mock_window := Window{}
	layout_parents(mut root, unsafe { nil })
	layout_positions(mut root, 0, 0, mut mock_window)

	// Despite global RTL, container is LTR
	// x starts at 0 + 10 (padding_left) = 10
	// Child 0: x = 10
	assert f32_are_close(root.children[0].shape.x, 10.0)
	// Child 1: x = 10 + 40 + 5 = 55
	assert f32_are_close(root.children[1].shape.x, 55.0)
}

// Test: RTL swaps left/right padding
fn test_layout_positions_rtl_padding_swap() {
	// Asymmetric padding: left=20 (start), right=5 (end)
	// In RTL, start is physical right, so right padding = 20, left padding = 5
	mut root := Layout{
		shape:    &Shape{
			x:           0
			y:           0
			width:       200
			height:      50
			axis:        .left_to_right
			text_dir:    .rtl
			padding:     Padding{
				left:   20
				right:  5
				top:    0
				bottom: 0
			}
			size_border: 0
			spacing:     0
		}
		children: [
			Layout{
				shape: &Shape{
					shape_type: .rectangle
					width:      30
					height:     50
				}
			},
		]
	}

	mut mock_window := Window{}
	layout_parents(mut root, unsafe { nil })
	layout_positions(mut root, 0, 0, mut mock_window)

	// RTL: start x = 0 + 200 - padding.left(20) = 180
	// Child 0: x = 180 - 30 = 150
	assert f32_are_close(root.children[0].shape.x, 150.0)
}

// Test: RTL column swaps left/right padding (column/none axis)
fn test_layout_positions_rtl_column_padding() {
	// Column with padding.left=20 (start), padding.right=5 (end)
	// In RTL column: physical left = end side → x starts at padding.right
	// Use h_align=.left to isolate padding behavior from alignment
	mut root := Layout{
		shape:    &Shape{
			x:           0
			y:           0
			width:       200
			height:      100
			axis:        .top_to_bottom
			h_align:     .left
			text_dir:    .rtl
			padding:     Padding{
				left:   20
				right:  5
				top:    0
				bottom: 0
			}
			size_border: 0
			spacing:     0
		}
		children: [
			Layout{
				shape: &Shape{
					shape_type: .rectangle
					width:      30
					height:     50
				}
			},
		]
	}

	mut mock_window := Window{}
	layout_parents(mut root, unsafe { nil })
	layout_positions(mut root, 0, 0, mut mock_window)

	// RTL column: x = 0 + padding.right(5) = 5
	assert f32_are_close(root.children[0].shape.x, 5.0)
}

// Test: RTL float anchor auto-mirror (bottom_left → bottom_right)
fn test_float_attach_rtl_mirror() {
	mut parent := Layout{
		shape: &Shape{
			x:        0
			y:        0
			width:    200
			height:   100
			text_dir: .rtl
		}
	}
	mut float_child := Layout{
		shape: &Shape{
			shape_type:    .rectangle
			width:         50
			height:        30
			float:         true
			float_anchor:  .bottom_left
			float_tie_off: .top_left
		}
	}
	parent.children = [float_child]
	layout_parents(mut parent, unsafe { nil })

	// Auto-mirror: bottom_left → bottom_right, top_left → top_right
	// anchor bottom_right: x = 0 + 200 = 200, y = 100
	// tie_off top_right: x = 200 - 50 = 150, y = 100
	x, y := float_attach_layout(&parent.children[0])
	assert f32_are_close(x, 150.0)
	assert f32_are_close(y, 100.0)
}

// Test: RTL column with symmetric padding and center align = same as LTR
fn test_layout_positions_rtl_column_symmetric() {
	// Center alignment is direction-independent. With symmetric padding,
	// the padding swap is a no-op, so RTL and LTR produce identical x.
	mut rtl_root := Layout{
		shape:    &Shape{
			x:           0
			y:           0
			width:       200
			height:      100
			axis:        .top_to_bottom
			h_align:     .center
			text_dir:    .rtl
			padding:     Padding{
				left:   10
				right:  10
				top:    0
				bottom: 0
			}
			size_border: 0
			spacing:     0
		}
		children: [
			Layout{
				shape: &Shape{
					shape_type: .rectangle
					width:      30
					height:     50
				}
			},
		]
	}

	mut ltr_root := Layout{
		shape:    &Shape{
			x:           0
			y:           0
			width:       200
			height:      100
			axis:        .top_to_bottom
			h_align:     .center
			text_dir:    .ltr
			padding:     Padding{
				left:   10
				right:  10
				top:    0
				bottom: 0
			}
			size_border: 0
			spacing:     0
		}
		children: [
			Layout{
				shape: &Shape{
					shape_type: .rectangle
					width:      30
					height:     50
				}
			},
		]
	}

	mut mock_window := Window{}
	layout_parents(mut rtl_root, unsafe { nil })
	layout_positions(mut rtl_root, 0, 0, mut mock_window)
	layout_parents(mut ltr_root, unsafe { nil })
	layout_positions(mut ltr_root, 0, 0, mut mock_window)

	// Symmetric padding + center align: RTL and LTR produce same x
	assert f32_are_close(rtl_root.children[0].shape.x, ltr_root.children[0].shape.x)
}
