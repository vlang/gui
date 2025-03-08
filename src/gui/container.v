module gui

import gx

// Container is the fundamental layout container in gui.
// It can be used to layout its children top-to-bottom or left_to_right.
// A `.none` direction allows coontainer to behave as a canvas with no additional layout.
pub struct Container implements UI_Tree {
pub mut:
	direction ShapeDirection = .top_to_bottom
	x         int
	y         int
	width     int
	height    int
	spacing   int
	sizing    Sizing
	padding   Padding
	fill      bool = true
	radius    int
	color     gx.Color = gx.rgba(0, 0, 0, 0)
	children  []UI_Tree
}

pub fn (c &Container) generate() Shape {
	return Shape{
		type:      .rectangle
		direction: c.direction
		x:         c.x
		y:         c.y
		width:     c.width
		height:    c.height
		spacing:   c.spacing
		sizing:    c.sizing
		padding:   c.padding
		fill:      c.fill
		radius:    c.radius
		color:     c.color
	}
}

pub struct ContainerConfig {
	RectangleConfig
pub:
	spacing  int
	padding  Padding
	children []UI_Tree
}

fn container(c ContainerConfig) &Container {
	return &Container{
		x:        c.x
		y:        c.y
		width:    c.width
		height:   c.height
		spacing:  c.spacing
		sizing:   c.sizing
		padding:  c.padding
		fill:     c.fill
		radius:   c.radius
		color:    c.color
		children: c.children
	}
}

// --- Common layout containers ---

pub fn column(c ContainerConfig) &Container {
	mut col := container(c)
	col.direction = .top_to_bottom
	return col
}

pub fn row(c ContainerConfig) &Container {
	mut row := container(c)
	row.direction = .left_to_right
	return row
}

pub fn canvas(c ContainerConfig) &Container {
	return container(c)
}
