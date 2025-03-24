module gui

import gg
import gx

struct Container implements View {
pub mut:
	id           string
	id_focus     FocusId
	axis         Axis
	x            f32
	y            f32
	width        f32
	min_width    f32
	height       f32
	min_height   f32
	spacing      f32
	sizing       Sizing
	padding      Padding
	fill         bool
	radius       int
	color        gx.Color
	on_char      fn (u32, &Window)                          = unsafe { nil }
	on_click     fn (string, MouseEvent, &Window)           = unsafe { nil }
	on_keydown   fn (gg.KeyCode, gg.Modifier, &Window) bool = unsafe { nil }
	on_mouseover fn (f32, f32, &Window)                     = unsafe { nil }
	amend_layout fn (mut ShapeTree, &Window)                = unsafe { nil }
	children     []View
}

fn (c &Container) generate(_ gg.Context) ShapeTree {
	return ShapeTree{
		shape: Shape{
			id:           c.id
			id_focus:     c.id_focus
			type:         .container
			axis:         c.axis
			x:            c.x
			y:            c.y
			width:        c.width
			height:       c.height
			spacing:      c.spacing
			sizing:       c.sizing
			padding:      c.padding
			fill:         c.fill
			radius:       c.radius
			color:        c.color
			min_width:    c.min_width
			min_height:   c.min_height
			on_click:     c.on_click
			on_char:      c.on_char
			on_keydown:   c.on_keydown
			amend_layout: c.amend_layout
		}
	}
}

// ContainerCfg is the common configuration struct for row, column and canvas containers
pub struct ContainerCfg {
pub:
	id           string
	id_focus     int
	x            f32
	y            f32
	width        f32
	min_width    f32
	height       f32
	min_height   f32
	sizing       Sizing
	fill         bool
	spacing      f32                                        = spacing_default
	radius       int                                        = radius_default
	color        gx.Color                                   = transparent
	padding      Padding                                    = padding_default
	on_char      fn (u32, &Window)                          = unsafe { nil }
	on_click     fn (string, MouseEvent, &Window)           = unsafe { nil }
	on_keydown   fn (gg.KeyCode, gg.Modifier, &Window) bool = unsafe { nil }
	on_mouseover fn (f32, f32, &Window)                     = unsafe { nil }
	amend_layout fn (mut ShapeTree, &Window)                = unsafe { nil }
	children     []View
}

// container is the fundamental layout container in gui. It is used to layout
// its children top-to-bottom or left_to_right. A `.none` axis allows a
// container to behave as a canvas with no additional layout.
fn container(c ContainerCfg) &Container {
	return &Container{
		id:           c.id
		id_focus:     c.id_focus
		x:            c.x
		y:            c.y
		width:        c.width
		min_width:    c.min_width
		height:       c.height
		min_height:   c.min_height
		color:        c.color
		fill:         c.fill
		padding:      c.padding
		radius:       c.radius
		sizing:       c.sizing
		spacing:      c.spacing
		on_click:     c.on_click
		on_char:      c.on_char
		on_keydown:   c.on_keydown
		on_mouseover: c.on_mouseover
		amend_layout: c.amend_layout
		children:     c.children
	}
}

// --- Common layout containers ---

// column arranges its children top to bottom. The gap between child items is
// determined by the spacing parameter.
pub fn column(cfg ContainerCfg) &Container {
	mut col := container(cfg)
	col.axis = .top_to_bottom
	return col
}

// row arranges its children left to right. The gap between child items is
// determined by the spacing parameter.
pub fn row(cfg ContainerCfg) &Container {
	mut row := container(cfg)
	row.axis = .left_to_right
	return row
}

// canvas does not arrange or otherwise layout its children.
pub fn canvas(cfg ContainerCfg) &Container {
	return container(cfg)
}
