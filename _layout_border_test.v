module gui

fn test_layout_widths_with_border() {
	// Root is the container with axis LTR
	mut root := Layout{
		shape:    &Shape{
			axis:        .left_to_right
			size_border: 5 // Border should add 10 to width (5 left + 5 right)
			padding:     Padding{
				left:   10
				right:  10
				top:    0
				bottom: 0
			}
			spacing:     0
			width:       0 // Will be calculated
		}
		children: [
			Layout{
				shape: &Shape{
					width:     50
					min_width: 50
				}
			},
		]
	}

	layout_widths(mut root)

	// Expected Width: Child(50) + Padding(10+10) + Border(5+5) = 80
	// Without border fix, it would be 70.
	assert f32_are_close(root.shape.width, 80.0)
	assert f32_are_close(root.shape.min_width, 80.0)
}

fn test_layout_heights_with_border() {
	// Root is the container with axis TTB
	mut root := Layout{
		shape:    &Shape{
			axis:        .top_to_bottom
			size_border: 5 // Border should add 10 to height (5 top + 5 bottom)
			padding:     Padding{
				left:   0
				right:  0
				top:    10
				bottom: 10
			}
			spacing:     0
			height:      0 // Will be calculated
		}
		children: [
			Layout{
				shape: &Shape{
					height:     50
					min_height: 50
				}
			},
		]
	}

	layout_heights(mut root)

	// Expected Height: Child(50) + Padding(10+10) + Border(5+5) = 80
	// Without border fix, it would be 70.
	assert f32_are_close(root.shape.height, 80.0)
	assert f32_are_close(root.shape.min_height, 80.0)
}

fn test_layout_position_with_border() {
	// Root Container
	mut root := Layout{
		shape:    &Shape{
			x:           0
			y:           0
			width:       100
			height:      100
			axis:        .left_to_right
			size_border: 5
			padding:     Padding{
				left:   10
				right:  10
				top:    10
				bottom: 10
			}
			spacing:     0
		}
		children: [
			Layout{
				shape: &Shape{
					width:  40
					height: 40
				}
			},
		]
	}

	mut mock_window := Window{}
	layout_parents(mut root, unsafe { nil })

	layout_positions(mut root, 0, 0, &mock_window)

	// Child Expected Position:
	// X: Root.x (0) + Pad.left (10) + Border (5) = 15
	// Y: Root.y (0) + Pad.top (10) + Border (5) = 15
	c1_x := root.children[0].shape.x
	c1_y := root.children[0].shape.y

	assert f32_are_close(c1_x, 15.0)
	assert f32_are_close(c1_y, 15.0)
}
