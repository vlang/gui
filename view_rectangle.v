module gui

@[heap]
pub struct RectangleCfg {
pub:
	name       string = 'rectangle'
	id         string
	width      f32
	height     f32
	min_width  f32
	min_height f32
	max_width  f32
	max_height f32
	disabled   bool
	invisible  bool
	sizing     Sizing
	color      Color = gui_theme.rectangle_style.color
	fill       bool  = gui_theme.rectangle_style.fill
	radius     f32   = gui_theme.rectangle_style.radius
}

// rectangle draws a rectangle (shocking!). Rectangles can be filled, outlined,
// colored and have radius corners.
pub fn rectangle(cfg &RectangleCfg) &ContainerView {
	// Technically, rectangle is a container but it has no children, axis or
	// padding and as such, behaves as a plain rectangle.
	container_cfg := &ContainerCfg{
		id:         cfg.id
		width:      cfg.width
		height:     cfg.height
		min_width:  cfg.width
		min_height: cfg.height
		sizing:     cfg.sizing
		disabled:   cfg.disabled
		invisible:  cfg.invisible
		color:      cfg.color
		fill:       cfg.fill
		padding:    padding_none
		radius:     cfg.radius
		spacing:    0
	}
	return container(container_cfg)
}
