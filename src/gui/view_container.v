module gui

import arrays
import gg

pub struct Container implements View {
pub:
	id             string
	id_focus       u32 // not sure this should be here
	x              f32
	y              f32
	width          f32
	min_width      f32
	max_width      f32
	height         f32
	min_height     f32
	max_height     f32
	color          Color   = gui_theme.container_style.color
	fill           bool    = gui_theme.container_style.fill
	padding        Padding = gui_theme.container_style.padding
	radius         f32     = gui_theme.container_style.radius
	spacing        f32     = gui_theme.container_style.spacing
	h_align        HorizontalAlign
	v_align        VerticalAlign
	clip           bool
	sizing         Sizing
	disabled       bool
	invisible      bool
	text           string
	id_scroll      u32
	scrollbar      bool
	scroll_cfg     ScrollbarCfg
	float          bool
	float_anchor   FloatAttach
	float_tie_off  FloatAttach
	float_offset_x f32
	float_offset_y f32
	on_char        fn (voidptr, mut Event, mut Window) = unsafe { nil }
	on_click       fn (voidptr, mut Event, mut Window) = unsafe { nil }
	on_keydown     fn (voidptr, mut Event, mut Window) = unsafe { nil }
	on_mouse_down  fn (voidptr, mut Event, mut Window) = unsafe { nil }
	on_mouse_move  fn (voidptr, mut Event, mut Window) = unsafe { nil }
	on_mouse_up    fn (voidptr, mut Event, mut Window) = unsafe { nil }
	amend_layout   fn (mut Layout, &Window)            = unsafe { nil }
	content        []View
mut:
	axis Axis
	cfg  &Cfg
}

fn (cfg &Container) generate(ctx &gg.Context) Layout {
	if cfg.invisible {
		return Layout{}
	}
	mut layout := Layout{
		shape: Shape{
			id:             cfg.id
			id_focus:       cfg.id_focus
			type:           .container
			axis:           cfg.axis
			x:              cfg.x
			y:              cfg.y
			width:          cfg.width
			min_width:      cfg.min_width
			max_width:      cfg.max_width
			height:         cfg.height
			min_height:     cfg.min_height
			max_height:     cfg.max_height
			clip:           cfg.clip
			spacing:        cfg.spacing
			sizing:         cfg.sizing
			padding:        cfg.padding
			fill:           cfg.fill
			h_align:        cfg.h_align
			v_align:        cfg.v_align
			radius:         cfg.radius
			color:          cfg.color
			disabled:       cfg.disabled
			float:          cfg.float
			float_anchor:   cfg.float_anchor
			float_tie_off:  cfg.float_tie_off
			float_offset_x: cfg.float_offset_x
			float_offset_y: cfg.float_offset_y
			text:           cfg.text
			text_style:     TextStyle{
				...gui_theme.text_style
				color: cfg.color
			}
			cfg:            cfg.cfg
			id_scroll:      cfg.id_scroll
			on_click:       cfg.on_click
			on_char:        cfg.on_char
			on_keydown:     cfg.on_keydown
			on_mouse_move:  cfg.on_mouse_move
			on_mouse_up:    cfg.on_mouse_up
			amend_layout:   cfg.amend_layout
		}
	}
	return layout
}

// ContainerCfg is the common configuration struct for row, column and canvas containers
pub struct ContainerCfg {
	cfg             &Cfg = unsafe { nil }
	on_click_layout fn (&Layout, &Event, &Window) bool = unsafe { nil }
pub:
	id             string
	width          f32
	height         f32
	min_width      f32
	min_height     f32
	max_width      f32
	max_height     f32
	disabled       bool
	invisible      bool
	sizing         Sizing
	id_focus       u32
	id_scroll      u32
	scrollbar_cfg  ScrollbarCfg
	scrollbar      bool
	x              f32
	y              f32
	clip           bool
	h_align        HorizontalAlign
	v_align        VerticalAlign
	text           string
	spacing        f32     = gui_theme.container_style.spacing
	radius         f32     = gui_theme.container_style.radius
	padding        Padding = gui_theme.container_style.padding
	color          Color   = gui_theme.container_style.color
	fill           bool    = gui_theme.container_style.fill
	float          bool
	float_anchor   FloatAttach
	float_tie_off  FloatAttach
	float_offset_x f32
	float_offset_y f32
	on_char        fn (voidptr, mut Event, mut Window) = unsafe { nil }
	on_click       fn (voidptr, mut Event, mut Window) = unsafe { nil }
	on_keydown     fn (voidptr, mut Event, mut Window) = unsafe { nil }
	on_mouse_move  fn (voidptr, mut Event, mut Window) = unsafe { nil }
	on_mouse_up    fn (voidptr, mut Event, mut Window) = unsafe { nil }
	amend_layout   fn (mut Layout, &Window)            = unsafe { nil }
	content        []View
}

// container is the fundamental layout container in gui. It is used to layout
// its content top-to-bottom or left_to_right. A `.none` axis allows a
// container to behave as a canvas with no additional layout.
fn container(cfg ContainerCfg) Container {
	content := match cfg.scrollbar && cfg.id_scroll > 0 {
		true {
			arrays.concat(cfg.content, scrollbar(ScrollbarCfg{
				...cfg.scrollbar_cfg
				id_track: cfg.id_scroll
			}))
		}
		else {
			cfg.content
		}
	}
	return Container{
		id:             cfg.id
		id_focus:       cfg.id_focus
		x:              cfg.x
		y:              cfg.y
		width:          cfg.width
		min_width:      if cfg.sizing.width == .fixed { cfg.width } else { cfg.min_width }
		max_width:      if cfg.sizing.width == .fixed { cfg.width } else { cfg.max_width }
		height:         cfg.height
		min_height:     if cfg.sizing.height == .fixed { cfg.height } else { cfg.min_height }
		max_height:     if cfg.sizing.height == .fixed { cfg.height } else { cfg.max_height }
		clip:           cfg.clip
		color:          cfg.color
		fill:           cfg.fill
		h_align:        cfg.h_align
		v_align:        cfg.v_align
		padding:        cfg.padding
		radius:         cfg.radius
		sizing:         cfg.sizing
		spacing:        cfg.spacing
		disabled:       cfg.disabled
		invisible:      cfg.invisible
		text:           cfg.text
		id_scroll:      cfg.id_scroll
		float:          cfg.float
		float_anchor:   cfg.float_anchor
		float_tie_off:  cfg.float_tie_off
		float_offset_x: cfg.float_offset_x
		float_offset_y: cfg.float_offset_y
		cfg:            cfg.cfg
		on_click:       cfg.on_click
		on_char:        cfg.on_char
		on_keydown:     cfg.on_keydown
		on_mouse_move:  cfg.on_mouse_move
		on_mouse_up:    cfg.on_mouse_up
		amend_layout:   cfg.amend_layout
		content:        content
	}
}

// --- Common layout containers ---

// column arranges its content top to bottom. The gap between child items is
// determined by the spacing parameter. See [ContainerCfg](#ContainerCfg)
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

// row arranges its content left to right. The gap between child items is
// determined by the spacing parameter. See [ContainerCfg](#ContainerCfg)
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

// canvas does not arrange or otherwise layout its content. See [ContainerCfg](#ContainerCfg)
pub fn canvas(cfg ContainerCfg) Container {
	mut canvas := container(cfg)
	if canvas.cfg == unsafe { nil } {
		canvas.cfg = &ContainerCfg{
			...cfg
		}
	}
	return canvas
}
