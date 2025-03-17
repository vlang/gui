module gui

import gx

pub struct RectangleCfg {
pub:
	id     string
	x      f32
	y      f32
	width  f32
	height f32
	color  gx.Color
	fill   bool
	radius int = radius_default
	sizing Sizing
}

// rectangle is one of the most useful and used UI controls.
// Rectangles can be filled, outlined and colored and can have radius
// corners.
pub fn rectangle(cfg RectangleCfg) &Container {
	// Technically, rectangle is a container but
	// it has no children, axis or paddin and as
	// such, behaves as a plain rectangle.
	container_cfg := ContainerCfg{
		id:      cfg.id
		x:       cfg.x
		y:       cfg.y
		width:   cfg.width
		height:  cfg.height
		color:   cfg.color
		fill:    cfg.fill
		padding: padding_none
		radius:  cfg.radius
		sizing:  cfg.sizing
		spacing: 0
	}
	return container(container_cfg)
}
