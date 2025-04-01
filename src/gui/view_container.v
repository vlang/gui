module gui

import gg
import gx

pub struct Container implements View {
	on_char      fn (voidptr, &gg.Event, &Window) bool = unsafe { nil }
	on_click     fn (voidptr, &gg.Event, &Window) bool = unsafe { nil }
	on_keydown   fn (voidptr, &gg.Event, &Window) bool = unsafe { nil }
	amend_layout fn (mut ShapeTree, &Window)           = unsafe { nil }
pub mut:
	id         string
	id_focus   u32
	axis       Axis
	x          f32
	y          f32
	width      f32
	min_width  f32
	max_width  f32
	height     f32
	min_height f32
	max_height f32
	clip       bool
	spacing    f32
	sizing     Sizing
	padding    Padding
	fill       bool
	h_align    HorizontalAlign
	v_align    VerticalAlign
	radius     f32
	color      gx.Color
	text       string
	cfg        voidptr
	children   []View
}

fn (cfg &Container) generate(_ gg.Context) ShapeTree {
	return ShapeTree{
		shape: Shape{
			id:           cfg.id
			id_focus:     cfg.id_focus
			type:         .container
			axis:         cfg.axis
			x:            cfg.x
			y:            cfg.y
			width:        cfg.width
			min_width:    cfg.min_width
			max_width:    cfg.max_width
			height:       cfg.height
			min_height:   cfg.min_height
			max_height:   cfg.max_height
			clip:         cfg.clip
			spacing:      cfg.spacing
			sizing:       cfg.sizing
			padding:      cfg.padding
			fill:         cfg.fill
			h_align:      cfg.h_align
			v_align:      cfg.v_align
			radius:       cfg.radius
			color:        cfg.color
			text:         cfg.text
			text_cfg:     gx.TextCfg{
				...gui_theme.text_cfg
				color: cfg.color
			}
			cfg:          cfg.cfg
			on_click:     cfg.on_click
			on_char:      cfg.on_char
			on_keydown:   cfg.on_keydown
			amend_layout: cfg.amend_layout
		}
	}
}

// ContainerCfg is the common configuration struct for row, column and canvas containers
pub struct ContainerCfg {
	cfg voidptr
pub:
	id           string
	id_focus     u32
	x            f32
	y            f32
	width        f32
	min_width    f32
	max_width    f32
	height       f32
	min_height   f32
	max_height   f32
	clip         bool
	sizing       Sizing
	fill         bool
	h_align      HorizontalAlign
	v_align      VerticalAlign
	text         string
	spacing      f32      = gui_theme.spacing_medium
	radius       f32      = gui_theme.radius_container
	padding      Padding  = gui_theme.padding_medium
	color        gx.Color = color_transparent
	on_char      fn (voidptr, &gg.Event, &Window) bool = unsafe { nil }
	on_click     fn (voidptr, &gg.Event, &Window) bool = unsafe { nil }
	on_keydown   fn (voidptr, &gg.Event, &Window) bool = unsafe { nil }
	amend_layout fn (mut ShapeTree, &Window)           = unsafe { nil }
	children     []View
}

// container is the fundamental layout container in gui. It is used to layout
// its children top-to-bottom or left_to_right. A `.none` axis allows a
// container to behave as a canvas with no additional layout.
fn container(cfg ContainerCfg) Container {
	return Container{
		id:           cfg.id
		id_focus:     cfg.id_focus
		x:            cfg.x
		y:            cfg.y
		width:        cfg.width
		min_width:    if cfg.sizing.width == .fixed { cfg.width } else { cfg.min_width }
		max_width:    if cfg.sizing.width == .fixed { cfg.width } else { cfg.max_width }
		height:       cfg.height
		min_height:   if cfg.sizing.height == .fixed { cfg.height } else { cfg.min_height }
		max_height:   if cfg.sizing.height == .fixed { cfg.height } else { cfg.max_height }
		clip:         cfg.clip
		color:        cfg.color
		fill:         cfg.fill
		h_align:      cfg.h_align
		v_align:      cfg.v_align
		padding:      cfg.padding
		radius:       cfg.radius
		sizing:       cfg.sizing
		spacing:      cfg.spacing
		text:         cfg.text
		cfg:          cfg.cfg
		on_click:     cfg.on_click
		on_char:      cfg.on_char
		on_keydown:   cfg.on_keydown
		amend_layout: cfg.amend_layout
		children:     cfg.children
	}
}

// --- Common layout containers ---

// column arranges its children top to bottom. The gap between child items is
// determined by the spacing parameter.
pub fn column(cfg ContainerCfg) Container {
	mut col := container(cfg)
	col.axis = .top_to_bottom
	if col.cfg == unsafe { nil } {
		col.cfg = &ContainerCfg{
			...cfg
		}
	}
	return col
}

// row arranges its children left to right. The gap between child items is
// determined by the spacing parameter.
pub fn row(cfg ContainerCfg) Container {
	mut row := container(cfg)
	row.axis = .left_to_right
	if row.cfg == unsafe { nil } {
		row.cfg = &ContainerCfg{
			...cfg
		}
	}
	return row
}

// canvas does not arrange or otherwise layout its children.
pub fn canvas(cfg ContainerCfg) Container {
	mut canvas := container(cfg)
	if canvas.cfg == unsafe { nil } {
		canvas.cfg = &ContainerCfg{
			...cfg
		}
	}
	return canvas
}
