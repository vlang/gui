module gui

import gx

// RectangleConfig
// Rectangles are one of the mose useful and used UI controls.
// Rectangles can be filled or outlined, colored and have radius
// corners. For the technially inclined rectangles are containers
// but don't have children and as such function as plain drawings.
pub struct RectangleConfig {
pub:
	id     string
	x      f32
	y      f32
	width  f32
	height f32
	sizing Sizing
	fill   bool
	radius int      = radius_default
	color  gx.Color = gx.rgba(0, 0, 0, 0)
}

// rectangle is a factory function for a rectangle
pub fn rectangle(c RectangleConfig) &Container {
	cfg := ContainerConfig{
		id:     c.id
		x:      c.x
		y:      c.y
		width:  c.width
		height: c.height
		sizing: c.sizing
		fill:   c.fill
		radius: c.radius
		color:  c.color
	}
	return container(cfg)
}
