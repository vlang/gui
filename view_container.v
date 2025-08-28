module gui

import arrays

// ContainerView members are arranged for packing to reduce memory footprint.

@[heap]
struct ContainerView implements View {
pub:
	id              string
	name            string // used internally, read-only
	text            string
	scrollbar_cfg_x &ScrollbarCfg = unsafe { nil }
	scrollbar_cfg_y &ScrollbarCfg = unsafe { nil }
	color           Color         = gui_theme.container_style.color
	padding         Padding       = gui_theme.container_style.padding
	sizing          Sizing
	x               f32
	y               f32
	width           f32
	min_width       f32
	max_width       f32
	height          f32
	min_height      f32
	max_height      f32
	radius          f32 = gui_theme.container_style.radius
	spacing         f32 = gui_theme.container_style.spacing
	float_offset_x  f32
	float_offset_y  f32
	id_focus        u32 // not sure this should be here
	id_scroll       u32
	on_char         fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	on_click        fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	on_keydown      fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	on_mouse_down   fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	on_mouse_move   fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	on_mouse_up     fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	amend_layout    fn (mut Layout, mut Window)            = unsafe { nil }
	on_hover        fn (mut Layout, mut Event, mut Window) = unsafe { nil }
	h_align         HorizontalAlign
	v_align         VerticalAlign
	scroll_mode     ScrollMode
	float_anchor    FloatAttach
	float_tie_off   FloatAttach
	fill            bool = gui_theme.container_style.fill
	clip            bool
	focus_skip      bool
	disabled        bool
	invisible       bool
	float           bool
	over_draw       bool
mut:
	content    []View
	tooltip    &TooltipCfg = unsafe { nil }
	cfg        voidptr
	shape_type ShapeType = .rectangle
	axis       Axis
}

fn (cv ContainerView) generate(mut window Window) Layout {
	assert cv.shape_type in [.rectangle, .circle]
	mut layout := get_layout()
	layout.shape.type = cv.shape_type
	layout.shape.id = cv.id
	layout.shape.id_focus = cv.id_focus
	layout.shape.axis = cv.axis
	layout.shape.name = cv.name
	layout.shape.x = cv.x
	layout.shape.y = cv.y
	layout.shape.width = cv.width
	layout.shape.min_width = cv.min_width
	layout.shape.max_width = cv.max_width
	layout.shape.height = cv.height
	layout.shape.min_height = cv.min_height
	layout.shape.max_height = cv.max_height
	layout.shape.clip = cv.clip
	layout.shape.focus_skip = cv.focus_skip
	layout.shape.spacing = cv.spacing
	layout.shape.sizing = cv.sizing
	layout.shape.padding = cv.padding
	layout.shape.fill = cv.fill
	layout.shape.h_align = cv.h_align
	layout.shape.v_align = cv.v_align
	layout.shape.radius = cv.radius
	layout.shape.color = cv.color
	layout.shape.disabled = cv.disabled
	layout.shape.float = cv.float
	layout.shape.float_anchor = cv.float_anchor
	layout.shape.float_tie_off = cv.float_tie_off
	layout.shape.float_offset_x = cv.float_offset_x
	layout.shape.float_offset_y = cv.float_offset_y
	layout.shape.text = cv.text
	layout.shape.text_style = TextStyle{
		...gui_theme.text_style
		color: cv.color
	}
	layout.shape.cfg = cv.cfg
	layout.shape.id_scroll = cv.id_scroll
	layout.shape.over_draw = cv.over_draw
	layout.shape.scroll_mode = cv.scroll_mode
	layout.shape.on_click = cv.on_click
	layout.shape.on_char = cv.on_char
	layout.shape.on_keydown = cv.on_keydown
	layout.shape.on_mouse_move = cv.on_mouse_move
	layout.shape.on_mouse_move_shape = if cv.tooltip != unsafe { nil } {
		cv.on_mouse_move_shape
	} else {
		unsafe { nil }
	}
	layout.shape.on_mouse_up = cv.on_mouse_up
	layout.shape.on_hover = cv.on_hover
	layout.shape.amend_layout = cv.amend_layout

	return layout
}

// ContainerCfg is the common configuration struct for row, column and canvas containers,
// Rows and columns have many options available. To list a few:
//
// - Focusable
// - Scrollable
// - Floatable
// - Sizable (fill, fit and fixed)
// - Alignable
// - Can be colored, outlined, or fillable
// - Can have radius corners
// - Can have text embedded in the border (group box)
//
// Focus is when a row or column can receive keyboard input. You can't type
// in a row or column so why is this needed? Styling. Oftentimes, the color
// of a row or column, particularly when used as a border, is modified
// based on the focus state.
//
// Enable scrolling by setting the `id_scroll` member to a non-zero value.
// Content that extends past the boundaries of the row (or column) are
// hidden until scrolled into view. When scrolling, scrollbars can
// optionally be enabled. One or both can be shown. Scrollbars can be
// hidden when content fits entirely within the container. Scrollbars can
// be made visible only when hovering over the scrollbar region. Scrollbars
// are floating views and be placed over or beside content as desired.
// Finally, scrolling can be restricted to vertical only or horizontal only
// via the `scroll_mode` property.
//
// Floating is particularly powerful. It allows drawing over other content.
// Menus are a good example of this. The menu code in Gui is just a
// composition of rows and columns (and text). The submenus are columns
// that float below or next to their parent item. The tricky part is the
// mouse handling. The drawing part is straightforward.
//
// Content can be aligned start, center, and end. Start and end are
// typically left and right but can change based on localization. Columns
// can align content top, middle, and bottom.
//
// Row and column are transparent by default. Change the color if desired.
// By default, the color is drawn as an outline. Set `fill` to true to fill
// the interior with color.
//
// The corners of a row or container can be square or round. The roundness
// of a corner is determined by the `radius` property.
//
// Text can be embedded in the outline of a row or column, near the
// top-left corner. This style of container is typically called a group
// box. Set the `text` property to enable this feature.
pub struct ContainerCfg {
	name string // internally set. read-only.
	axis Axis
mut:
	cfg voidptr = unsafe { nil }
pub:
	id              string
	text            string
	scrollbar_cfg_x &ScrollbarCfg = unsafe { nil }
	scrollbar_cfg_y &ScrollbarCfg = unsafe { nil }
	tooltip         &TooltipCfg   = unsafe { nil }
	color           Color         = gui_theme.container_style.color
	padding         Padding       = gui_theme.container_style.padding
	sizing          Sizing
	content         []View
	on_char         fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	on_click        fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	on_any_click    fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	on_keydown      fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	on_mouse_move   fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	on_mouse_up     fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	amend_layout    fn (mut Layout, mut Window)            = unsafe { nil }
	on_hover        fn (mut Layout, mut Event, mut Window) = unsafe { nil }
	width           f32
	height          f32
	min_width       f32
	min_height      f32
	max_width       f32
	max_height      f32
	x               f32
	y               f32
	spacing         f32 = gui_theme.container_style.spacing
	radius          f32 = gui_theme.container_style.radius
	float_offset_x  f32
	float_offset_y  f32
	id_focus        u32
	id_scroll       u32
	scroll_mode     ScrollMode
	h_align         HorizontalAlign
	v_align         VerticalAlign
	float_anchor    FloatAttach
	float_tie_off   FloatAttach
	disabled        bool
	invisible       bool
	clip            bool
	focus_skip      bool
	over_draw       bool
	fill            bool = gui_theme.container_style.fill
	float           bool
}

// container is the fundamental layout container in gui. It is used to layout
// its content top-to-bottom or left_to_right. A `.none` axis allows a
// container to behave as a canvas with no additional layout.
fn container(cfg ContainerCfg) View {
	if cfg.invisible {
		return ContainerView{
			over_draw: true // removes it from spacing calculations
			padding:   padding_none
		}
	}

	mut extra_content := []View{cap: 3}

	if cfg.id_scroll > 0 {
		if cfg.scrollbar_cfg_x != unsafe { nil } {
			if cfg.scrollbar_cfg_x.overflow != .hidden {
				extra_content << scrollbar(ScrollbarCfg{
					...cfg.scrollbar_cfg_x
					orientation: .horizontal
					id_track:    cfg.id_scroll
				})
			}
		} else {
			extra_content << scrollbar(ScrollbarCfg{
				orientation: .horizontal
				id_track:    cfg.id_scroll
			})
		}
	}
	if cfg.id_scroll > 0 {
		if cfg.scrollbar_cfg_y != unsafe { nil } {
			if cfg.scrollbar_cfg_y.overflow != .hidden {
				extra_content << scrollbar(ScrollbarCfg{
					...cfg.scrollbar_cfg_y
					orientation: .vertical
					id_track:    cfg.id_scroll
				})
			}
		} else {
			extra_content << scrollbar(ScrollbarCfg{
				orientation: .vertical
				id_track:    cfg.id_scroll
			})
		}
	}
	if gui_tooltip.id != 0 {
		if cfg.tooltip != unsafe { nil } {
			if cfg.tooltip.hash() == gui_tooltip.id {
				extra_content << tooltip(cfg.tooltip)
			}
		}
	}

	content := match extra_content.len > 0 {
		true { arrays.append(cfg.content, extra_content) }
		else { cfg.content }
	}

	return ContainerView{
		id:              cfg.id
		id_focus:        cfg.id_focus
		axis:            cfg.axis
		name:            cfg.name
		x:               cfg.x
		y:               cfg.y
		width:           cfg.width
		min_width:       if cfg.sizing.width == .fixed { cfg.width } else { cfg.min_width }
		max_width:       if cfg.sizing.width == .fixed { cfg.width } else { cfg.max_width }
		height:          cfg.height
		min_height:      if cfg.sizing.height == .fixed { cfg.height } else { cfg.min_height }
		max_height:      if cfg.sizing.height == .fixed { cfg.height } else { cfg.max_height }
		clip:            cfg.clip
		color:           cfg.color
		fill:            cfg.fill
		h_align:         cfg.h_align
		v_align:         cfg.v_align
		padding:         cfg.padding
		radius:          cfg.radius
		sizing:          cfg.sizing
		spacing:         cfg.spacing
		disabled:        cfg.disabled
		invisible:       cfg.invisible
		text:            cfg.text
		id_scroll:       cfg.id_scroll
		over_draw:       cfg.over_draw
		scroll_mode:     cfg.scroll_mode
		scrollbar_cfg_x: &cfg.scrollbar_cfg_x
		scrollbar_cfg_y: &cfg.scrollbar_cfg_y
		float:           cfg.float
		float_anchor:    cfg.float_anchor
		float_tie_off:   cfg.float_tie_off
		float_offset_x:  cfg.float_offset_x
		float_offset_y:  cfg.float_offset_y
		tooltip:         cfg.tooltip
		cfg:             cfg.cfg
		on_click:        if cfg.on_any_click != unsafe { nil } {
			cfg.on_any_click
		} else {
			cfg.left_click()
		}
		on_char:         cfg.on_char
		on_keydown:      cfg.on_keydown
		on_mouse_move:   cfg.on_mouse_move
		on_mouse_up:     cfg.on_mouse_up
		on_hover:        cfg.on_hover
		amend_layout:    cfg.amend_layout
		content:         content
	}
}

// --- Common layout containers ---

// column arranges its content top to bottom. The gap between child items is
// determined by the spacing parameter. See [ContainerCfg](#ContainerCfg)
pub fn column(cfg ContainerCfg) View {
	name := if cfg.name.len == 0 { 'column' } else { cfg.name }
	mut container_cfg := &ContainerCfg{
		...cfg
		axis: .top_to_bottom
		name: name
	}
	if cfg.cfg == unsafe { nil } {
		container_cfg.cfg = &cfg
	}
	return container(container_cfg)
}

// row arranges its content left to right. The gap between child items is
// determined by the spacing parameter. See [ContainerCfg](#ContainerCfg)
pub fn row(cfg ContainerCfg) View {
	name := if cfg.name.len == 0 { 'row' } else { cfg.name }
	mut container_cfg := &ContainerCfg{
		...cfg
		axis: .left_to_right
		name: name
	}
	if cfg.cfg == unsafe { nil } {
		container_cfg.cfg = &cfg
	}
	return container(container_cfg)
}

// canvas does not arrange or otherwise layout its content. See [ContainerCfg](#ContainerCfg)
pub fn canvas(cfg ContainerCfg) View {
	name := if cfg.name.len == 0 { 'canvas' } else { cfg.name }
	mut container_cfg := &ContainerCfg{
		...cfg
		name: name
	}
	if cfg.cfg == unsafe { nil } {
		container_cfg.cfg = &cfg
	}
	return container(container_cfg)
}

pub fn circle(cfg ContainerCfg) View {
	name := if cfg.name.len == 0 { 'circle' } else { cfg.name }
	mut container_cfg := &ContainerCfg{
		...cfg
		name: name
	}
	mut circle := container(container_cfg) as ContainerView
	circle.shape_type = .circle
	if cfg.cfg == unsafe { nil } {
		container_cfg.cfg = &cfg
	}
	return circle
}

fn (mut cfg ContainerView) on_mouse_move_shape(shape &Shape, mut e Event, mut w Window) {
	if cfg.tooltip != unsafe { nil } {
		if cfg.tooltip.content.len > 0 {
			w.animation_add(mut cfg.tooltip.animation_tooltip())
			gui_tooltip.bounds = DrawClip{
				x:      shape.x
				y:      shape.y
				width:  shape.width
				height: shape.height
			}
		}
	}
}

fn (cfg &ContainerCfg) left_click() fn (&ContainerCfg, mut Event, mut Window) {
	if cfg.on_click == unsafe { nil } {
		return cfg.on_click
	}
	on_click := cfg.on_click
	return fn [on_click] (_cfg voidptr, mut e Event, mut w Window) {
		if e.mouse_button == .left {
			on_click(_cfg, mut e, mut w)
		}
	}
}
