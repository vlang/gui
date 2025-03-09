module gui

import gx

// Container is the fundamental layout container in gui.
// It can be used to layout its children top-to-bottom or left_to_right.
// A `.none` direction allows coontainer to behave as a canvas with no additional layout.
pub struct Container implements UI_Tree {
pub mut:
	id        string
	direction ShapeDirection = .top_to_bottom
	x         f32
	y         f32
	width     f32
	height    f32
	spacing   f32
	sizing    Sizing
	padding   Padding
	fill      bool = true
	radius    int
	color     gx.Color = gx.rgba(0, 0, 0, 0)
	children  []UI_Tree
}

pub fn (c &Container) generate() Shape {
	return Shape{
		id:        c.id
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
pub:
	id       string
	x        f32
	y        f32
	width    f32
	height   f32
	spacing  f32
	sizing   Sizing
	fill     bool
	radius   int
	color    gx.Color = gx.rgba(0, 0, 0, 0)
	padding  Padding
	children []UI_Tree
}

fn container(c ContainerConfig) &Container {
	return &Container{
		id:       c.id
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
