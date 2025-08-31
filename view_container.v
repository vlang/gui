module gui

import arrays
import rand

// ContainerView members are arranged for packing to reduce memory footprint.

@[heap]
struct ContainerView implements View {
	uid       u64      = rand.u64()
	view_type ViewType = .container
mut:
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
	content         []View
	tooltip         &TooltipCfg = unsafe { nil }
	cfg             voidptr
	shape_type      ShapeType = .rectangle
	axis            Axis
}

fn (cv ContainerView) generate(mut _ Window) Layout {
	assert cv.shape_type in [.rectangle, .circle]
	layout := Layout{
		shape: &Shape{
			type:                cv.shape_type
			id:                  cv.id
			id_focus:            cv.id_focus
			axis:                cv.axis
			name:                cv.name
			x:                   cv.x
			y:                   cv.y
			width:               cv.width
			min_width:           cv.min_width
			max_width:           cv.max_width
			height:              cv.height
			min_height:          cv.min_height
			max_height:          cv.max_height
			clip:                cv.clip
			focus_skip:          cv.focus_skip
			spacing:             cv.spacing
			sizing:              cv.sizing
			padding:             cv.padding
			fill:                cv.fill
			h_align:             cv.h_align
			v_align:             cv.v_align
			radius:              cv.radius
			color:               cv.color
			disabled:            cv.disabled
			float:               cv.float
			float_anchor:        cv.float_anchor
			float_tie_off:       cv.float_tie_off
			float_offset_x:      cv.float_offset_x
			float_offset_y:      cv.float_offset_y
			text:                cv.text
			text_style:          TextStyle{
				...gui_theme.text_style
				color: cv.color
			}
			cfg:                 cv.cfg
			id_scroll:           cv.id_scroll
			over_draw:           cv.over_draw
			scroll_mode:         cv.scroll_mode
			on_click:            cv.on_click
			on_char:             cv.on_char
			on_keydown:          cv.on_keydown
			on_mouse_move:       cv.on_mouse_move
			on_mouse_move_shape: if cv.tooltip != unsafe { nil } {
				cv.on_mouse_move_shape
			} else {
				unsafe { nil }
			}
			on_mouse_up:         cv.on_mouse_up
			on_hover:            cv.on_hover
			amend_layout:        cv.amend_layout
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

	mut cv := view_pool.allocate_container_view()

	cv.id = cfg.id
	cv.id_focus = cfg.id_focus
	cv.axis = cfg.axis
	cv.name = cfg.name
	cv.x = cfg.x
	cv.y = cfg.y
	cv.width = cfg.width
	cv.min_width = if cfg.sizing.width == .fixed { cfg.width } else { cfg.min_width }
	cv.max_width = if cfg.sizing.width == .fixed { cfg.width } else { cfg.max_width }
	cv.height = cfg.height
	cv.min_height = if cfg.sizing.height == .fixed { cfg.height } else { cfg.min_height }
	cv.max_height = if cfg.sizing.height == .fixed { cfg.height } else { cfg.max_height }
	cv.clip = cfg.clip
	cv.color = cfg.color
	cv.fill = cfg.fill
	cv.h_align = cfg.h_align
	cv.v_align = cfg.v_align
	cv.padding = cfg.padding
	cv.radius = cfg.radius
	cv.sizing = cfg.sizing
	cv.spacing = cfg.spacing
	cv.disabled = cfg.disabled
	cv.invisible = cfg.invisible
	cv.text = cfg.text
	cv.id_scroll = cfg.id_scroll
	cv.over_draw = cfg.over_draw
	cv.scroll_mode = cfg.scroll_mode
	cv.scrollbar_cfg_x = &cfg.scrollbar_cfg_x
	cv.scrollbar_cfg_y = &cfg.scrollbar_cfg_y
	cv.float = cfg.float
	cv.float_anchor = cfg.float_anchor
	cv.float_tie_off = cfg.float_tie_off
	cv.float_offset_x = cfg.float_offset_x
	cv.float_offset_y = cfg.float_offset_y
	cv.tooltip = cfg.tooltip
	cv.cfg = cfg.cfg
	cv.on_click = if cfg.on_any_click != unsafe { nil } {
		cfg.on_any_click
	} else {
		cfg.left_click()
	}
	cv.on_char = cfg.on_char
	cv.on_keydown = cfg.on_keydown
	cv.on_mouse_move = cfg.on_mouse_move
	cv.on_mouse_up = cfg.on_mouse_up
	cv.on_hover = cfg.on_hover
	cv.amend_layout = cfg.amend_layout
	cv.content = content

	return cv
}

pub fn (mut cv ContainerView) reset_fields() {
	// uid and view_type are not changed or pool logic will break
	cv.id = ''
	cv.name = ''
	cv.text = ''
	cv.scrollbar_cfg_x = unsafe { nil }
	cv.scrollbar_cfg_y = unsafe { nil }
	cv.color = gui_theme.container_style.color
	cv.padding = gui_theme.container_style.padding
	cv.sizing = Sizing{}
	cv.x = 0.0
	cv.y = 0.0
	cv.width = 0.0
	cv.min_width = 0.0
	cv.max_width = 0.0
	cv.height = 0.0
	cv.min_height = 0.0
	cv.max_height = 0.0
	cv.radius = gui_theme.container_style.radius
	cv.spacing = gui_theme.container_style.spacing
	cv.float_offset_x = 0.0
	cv.float_offset_y = 0.0
	cv.id_focus = 0
	cv.id_scroll = 0
	cv.on_char = unsafe { nil }
	cv.on_click = unsafe { nil }
	cv.on_keydown = unsafe { nil }
	cv.on_mouse_down = unsafe { nil }
	cv.on_mouse_move = unsafe { nil }
	cv.on_mouse_up = unsafe { nil }
	cv.amend_layout = unsafe { nil }
	cv.on_hover = unsafe { nil }
	cv.h_align = .start
	cv.v_align = .top
	cv.scroll_mode = .both
	cv.float_anchor = .top_left
	cv.float_tie_off = .top_left
	cv.fill = gui_theme.container_style.fill
	cv.clip = false
	cv.focus_skip = false
	cv.disabled = false
	cv.invisible = false
	cv.float = false
	cv.over_draw = false
	cv.content = []View{}
	cv.tooltip = unsafe { nil }
	cv.cfg = unsafe { nil }
	cv.shape_type = .rectangle
	cv.axis = .none
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
