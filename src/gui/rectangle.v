module gui

import gx

pub struct RectangleCfg {
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

// rectangle is one of the most useful and used UI controls.
// Rectangles can be filled, outlined and colored and can have radius
// corners.
pub fn rectangle(cfg RectangleCfg) &Container {
	container_cfg := ContainerCfg{
		id:      cfg.id
		x:       cfg.x
		y:       cfg.y
		width:   cfg.width
		height:  cfg.height
		sizing:  cfg.sizing
		fill:    cfg.fill
		radius:  cfg.radius
		color:   cfg.color
		padding: Padding{0, 0, 0, 0}
		spacing: 0
	}
	return container(container_cfg)
}
