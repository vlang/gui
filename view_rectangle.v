module gui

@[minify]
pub struct RectangleCfg {
pub:
	name         string = 'rectangle'
	id           string
	sizing       Sizing
	color        Color     = gui_theme.rectangle_style.color
	color_border Color     = gui_theme.rectangle_style.color_border
	gradient     &Gradient = gui_theme.rectangle_style.gradient
	width        f32
	height       f32
	min_width    f32
	min_height   f32
	max_height   f32
	radius       f32 = gui_theme.rectangle_style.radius
	border_width f32 = gui_theme.rectangle_style.border_width
	disabled     bool
	invisible    bool
	fill         bool = gui_theme.rectangle_style.fill
}

// rectangle draws a rectangle (shocking!). Rectangles can be filled, outlined,
// colored and have radius corners.
pub fn rectangle(cfg RectangleCfg) View {
	// Technically, rectangle is a container but it has no children, axis or
	// padding and as such, behaves as a plain rectangle.
	container_cfg := ContainerCfg{
		id:           cfg.id
		width:        cfg.width
		height:       cfg.height
		min_width:    cfg.width
		min_height:   cfg.height
		sizing:       cfg.sizing
		disabled:     cfg.disabled
		invisible:    cfg.invisible
		color:        cfg.color
		gradient:     cfg.gradient
		fill:         cfg.fill
		padding:      padding_none
		radius:       cfg.radius
		border_color: cfg.color
		border_width: cfg.border_width
		spacing:      0
	}
	return container(container_cfg)
}
