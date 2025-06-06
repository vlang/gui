module gui

@[heap]
struct ContainerView implements View {
pub:
	id              string
	id_focus        u32 // not sure this should be here
	x               f32
	y               f32
	width           f32
	min_width       f32
	max_width       f32
	height          f32
	min_height      f32
	max_height      f32
	color           Color   = gui_theme.container_style.color
	fill            bool    = gui_theme.container_style.fill
	padding         Padding = gui_theme.container_style.padding
	radius          f32     = gui_theme.container_style.radius
	spacing         f32     = gui_theme.container_style.spacing
	h_align         HorizontalAlign
	v_align         VerticalAlign
	clip            bool
	focus_skip      bool
	sizing          Sizing
	disabled        bool
	invisible       bool
	text            string
	float           bool
	float_anchor    FloatAttach
	float_tie_off   FloatAttach
	float_offset_x  f32
	float_offset_y  f32
	id_scroll       u32
	over_draw       bool
	scroll_mode     ScrollMode
	scrollbar_cfg_x ScrollbarCfg
	scrollbar_cfg_y ScrollbarCfg
	on_char         fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	on_click        fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	on_keydown      fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	on_mouse_down   fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	on_mouse_move   fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	on_mouse_up     fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	amend_layout    fn (mut Layout, mut Window)            = unsafe { nil }
	on_hover        fn (mut Layout, mut Event, mut Window) = unsafe { nil }
mut:
	shape_type ShapeType = .rectangle
	axis       Axis
	cfg        voidptr
	content    []View
}

fn (cv &ContainerView) generate(mut _ Window) Layout {
	if cv.invisible {
		return Layout{}
	}
	assert cv.shape_type in [.rectangle, .circle]
	mut layout := Layout{
		shape: Shape{
			type:           cv.shape_type
			id:             cv.id
			id_focus:       cv.id_focus
			axis:           cv.axis
			x:              cv.x
			y:              cv.y
			width:          cv.width
			min_width:      cv.min_width
			max_width:      cv.max_width
			height:         cv.height
			min_height:     cv.min_height
			max_height:     cv.max_height
			clip:           cv.clip
			focus_skip:     cv.focus_skip
			spacing:        cv.spacing
			sizing:         cv.sizing
			padding:        cv.padding
			fill:           cv.fill
			h_align:        cv.h_align
			v_align:        cv.v_align
			radius:         cv.radius
			color:          cv.color
			disabled:       cv.disabled
			float:          cv.float
			float_anchor:   cv.float_anchor
			float_tie_off:  cv.float_tie_off
			float_offset_x: cv.float_offset_x
			float_offset_y: cv.float_offset_y
			text:           cv.text
			text_style:     TextStyle{
				...gui_theme.text_style
				color: cv.color
			}
			cfg:            cv.cfg
			id_scroll:      cv.id_scroll
			over_draw:      cv.over_draw
			scroll_mode:    cv.scroll_mode
			on_click:       cv.on_click
			on_char:        cv.on_char
			on_keydown:     cv.on_keydown
			on_mouse_move:  cv.on_mouse_move
			on_mouse_up:    cv.on_mouse_up
			on_hover:       cv.on_hover
			amend_layout:   cv.amend_layout
		}
	}
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
@[heap]
pub struct ContainerCfg {
	axis Axis
mut:
	cfg voidptr = unsafe { nil }
pub:
	id              string
	width           f32
	height          f32
	min_width       f32
	min_height      f32
	max_width       f32
	max_height      f32
	disabled        bool
	invisible       bool
	sizing          Sizing
	id_focus        u32
	id_scroll       u32
	over_draw       bool
	scroll_mode     ScrollMode
	scrollbar_cfg_x ScrollbarCfg
	scrollbar_cfg_y ScrollbarCfg
	x               f32
	y               f32
	clip            bool
	focus_skip      bool
	h_align         HorizontalAlign
	v_align         VerticalAlign
	text            string
	spacing         f32     = gui_theme.container_style.spacing
	radius          f32     = gui_theme.container_style.radius
	padding         Padding = gui_theme.container_style.padding
	color           Color   = gui_theme.container_style.color
	fill            bool    = gui_theme.container_style.fill
	float           bool
	float_anchor    FloatAttach
	float_tie_off   FloatAttach
	float_offset_x  f32
	float_offset_y  f32
	on_char         fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	on_click        fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	on_keydown      fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	on_mouse_move   fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	on_mouse_up     fn (voidptr, mut Event, mut Window)    = unsafe { nil }
	amend_layout    fn (mut Layout, mut Window)            = unsafe { nil }
	on_hover        fn (mut Layout, mut Event, mut Window) = unsafe { nil }
	content         []View
}

// container is the fundamental layout container in gui. It is used to layout
// its content top-to-bottom or left_to_right. A `.none` axis allows a
// container to behave as a canvas with no additional layout.
fn container(cfg &ContainerCfg) ContainerView {
	mut content := []View{}
	content << cfg.content
	if cfg.id_scroll > 0 && cfg.scrollbar_cfg_x.overflow != .hidden {
		content << scrollbar(ScrollbarCfg{
			...cfg.scrollbar_cfg_x
			orientation: .horizontal
			id_track:    cfg.id_scroll
		})
	}
	if cfg.id_scroll > 0 && cfg.scrollbar_cfg_y.overflow != .hidden {
		content << scrollbar(ScrollbarCfg{
			...cfg.scrollbar_cfg_y
			orientation: .vertical
			id_track:    cfg.id_scroll
		})
	}

	return ContainerView{
		id:              cfg.id
		id_focus:        cfg.id_focus
		axis:            cfg.axis
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
		scrollbar_cfg_x: cfg.scrollbar_cfg_x
		scrollbar_cfg_y: cfg.scrollbar_cfg_y
		float:           cfg.float
		float_anchor:    cfg.float_anchor
		float_tie_off:   cfg.float_tie_off
		float_offset_x:  cfg.float_offset_x
		float_offset_y:  cfg.float_offset_y
		cfg:             cfg.cfg
		on_click:        cfg.on_click
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
pub fn column(cfg &ContainerCfg) ContainerView {
	mut container_cfg := &ContainerCfg{
		...cfg
		axis: .top_to_bottom
	}
	if cfg.cfg == unsafe { nil } {
		container_cfg.cfg = container_cfg
	}
	return container(container_cfg)
}

// row arranges its content left to right. The gap between child items is
// determined by the spacing parameter. See [ContainerCfg](#ContainerCfg)
pub fn row(cfg &ContainerCfg) ContainerView {
	mut container_cfg := &ContainerCfg{
		...cfg
		axis: .left_to_right
	}
	if cfg.cfg == unsafe { nil } {
		container_cfg.cfg = container_cfg
	}
	return container(container_cfg)
}

// canvas does not arrange or otherwise layout its content. See [ContainerCfg](#ContainerCfg)
pub fn canvas(cfg &ContainerCfg) ContainerView {
	mut container_cfg := &ContainerCfg{
		...cfg
	}
	if cfg.cfg == unsafe { nil } {
		container_cfg.cfg = container_cfg
	}
	return container(container_cfg)
}

pub fn circle(cfg &ContainerCfg) ContainerView {
	mut container_cfg := &ContainerCfg{
		...cfg
	}
	if cfg.cfg == unsafe { nil } {
		container_cfg.cfg = container_cfg
	}
	mut circle := container(container_cfg)
	circle.shape_type = .circle
	return circle
}
