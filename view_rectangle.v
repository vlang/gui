module gui

@[minify]
pub struct RectangleCfg {
pub:
	name            string = 'rectangle'
	id              string
	sizing          Sizing
	color           Color      = gui_theme.rectangle_style.color
	color_border    Color      = gui_theme.rectangle_style.color_border
	gradient        &Gradient  = gui_theme.rectangle_style.gradient
	border_gradient &Gradient  = gui_theme.rectangle_style.border_gradient
	shadow          &BoxShadow = gui_theme.rectangle_style.shadow
	width           f32
	height          f32
	min_width       f32
	min_height      f32
	max_height      f32
	radius          f32 = gui_theme.rectangle_style.radius
	blur_radius     f32 = gui_theme.rectangle_style.blur_radius
	size_border     f32 = gui_theme.rectangle_style.size_border
	disabled        bool
	invisible       bool
}

// rectangle draws a rectangle (shocking!). Rectangles can be filled, outlined,
// colored and have radius corners.
pub fn rectangle(cfg RectangleCfg) View {
	// Technically, rectangle is a container but it has no children, axis or
	// padding and as such, behaves as a plain rectangle.
	container_cfg := ContainerCfg{
		id:              cfg.id
		width:           cfg.width
		height:          cfg.height
		min_width:       cfg.width
		min_height:      cfg.height
		sizing:          cfg.sizing
		disabled:        cfg.disabled
		invisible:       cfg.invisible
		color:           cfg.color
		color_border:    cfg.color_border
		gradient:        cfg.gradient
		border_gradient: cfg.border_gradient
		shadow:          cfg.shadow
		blur_radius:     cfg.blur_radius
		padding:         padding_none
		radius:          cfg.radius
		size_border:     cfg.size_border
		spacing:         0
	}
	return container(container_cfg)
}
