module gui

// view_container.v is the core container view implementation for the GUI library.
// It provides container views that can layout child elements vertically (column),
// horizontally (row), or freely (canvas). Containers support features like:
// - Flexible sizing and alignment
// - Scrolling with customizable scrollbars
// - Mouse/keyboard event handling
// - Tooltips
// - Floating/overlay positioning
// - Border styling with optional text labels
// - Clipping of child content
//
// The main types defined are:
// - ContainerView: The base container view implementation
// - ContainerCfg: Configuration struct for creating containers
//
// This file also provides the core container factory functions:
// - column(): Creates a vertical container
// - row(): Creates a horizontal container
// - canvas(): Creates a free-form container
// - circle(): Creates a circular container
import arrays

@[minify]
struct ContainerView implements View {
pub:
	id             string
	name           string // used internally, read-only
	text           string
	color          Color   = gui_theme.container_style.color
	padding        Padding = gui_theme.container_style.padding
	sizing         Sizing
	x              f32
	y              f32
	width          f32
	min_width      f32
	max_width      f32
	height         f32
	min_height     f32
	max_height     f32
	radius         f32 = gui_theme.container_style.radius
	spacing        f32 = gui_theme.container_style.spacing
	float_offset_x f32
	float_offset_y f32
	id_focus       u32
	id_scroll      u32
	h_align        HorizontalAlign
	v_align        VerticalAlign
	scroll_mode    ScrollMode
	float_anchor   FloatAttach
	float_tie_off  FloatAttach
	fill           bool = gui_theme.container_style.fill
	clip           bool
	focus_skip     bool
	disabled       bool
	invisible      bool
	float          bool
	over_draw      bool
mut:
	content       []View
	tooltip       &TooltipCfg                            = unsafe { nil }
	on_char       fn (&Layout, mut Event, mut Window)    = unsafe { nil }
	on_click      fn (&Layout, mut Event, mut Window)    = unsafe { nil }
	on_keydown    fn (&Layout, mut Event, mut Window)    = unsafe { nil }
	on_mouse_move fn (&Layout, mut Event, mut Window)    = unsafe { nil }
	on_mouse_up   fn (&Layout, mut Event, mut Window)    = unsafe { nil }
	amend_layout  fn (mut Layout, mut Window)            = unsafe { nil }
	on_hover      fn (mut Layout, mut Event, mut Window) = unsafe { nil }
	shape_type    ShapeType = .rectangle
	axis          Axis
}

fn (mut cv ContainerView) generate_layout(mut _ Window) Layout {
	assert cv.shape_type in [.rectangle, .circle]
	$if !prod {
		gui_stats.increment_layouts()
	}
	layout := Layout{
		shape: &Shape{
			shape_type:     cv.shape_type
			id:             cv.id
			id_focus:       cv.id_focus
			axis:           cv.axis
			name:           cv.name
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
			text_style:     if cv.color == gui_theme.text_style.color {
				gui_theme.text_style
			} else {
				TextStyle{
					...gui_theme.text_style
					color: cv.color
				}
			}
			id_scroll:      cv.id_scroll
			over_draw:      cv.over_draw
			scroll_mode:    cv.scroll_mode
			on_click:       cv.on_click
			on_char:        cv.on_char
			on_keydown:     cv.on_keydown
			on_mouse_move:  if cv.tooltip != unsafe { nil } {
				fn [cv] (layout &Layout, mut e Event, mut w Window) {
					cv.on_mouse_move_tooltip(layout.shape, mut e, mut w)
					if cv.on_mouse_move != unsafe { nil } {
						cv.on_mouse_move(layout, mut e, mut w)
					}
					e.is_handled = true
				}
			} else {
				cv.on_mouse_move
			}
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
@[minify]
pub struct ContainerCfg {
pub mut:
	name string // internally set. read-only.
	axis Axis
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
	on_char         fn (&Layout, mut Event, mut Window)    = unsafe { nil }
	on_click        fn (&Layout, mut Event, mut Window)    = unsafe { nil }
	on_any_click    fn (&Layout, mut Event, mut Window)    = unsafe { nil }
	on_keydown      fn (&Layout, mut Event, mut Window)    = unsafe { nil }
	on_mouse_move   fn (&Layout, mut Event, mut Window)    = unsafe { nil }
	on_mouse_up     fn (&Layout, mut Event, mut Window)    = unsafe { nil }
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
	$if !prod {
		gui_stats.increment_container_views()
	}

	if cfg.invisible {
		return invisible_container_view()
	}

	mut extra_content := []View{cap: 3}

	if cfg.id_scroll > 0 {
		if cfg.scrollbar_cfg_x != unsafe { nil } {
			if cfg.scrollbar_cfg_x.overflow != .hidden {
				extra_content << scrollbar(ScrollbarCfg{
					...*cfg.scrollbar_cfg_x
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
		if cfg.scrollbar_cfg_y != unsafe { nil } {
			if cfg.scrollbar_cfg_y.overflow != .hidden {
				extra_content << scrollbar(ScrollbarCfg{
					...*cfg.scrollbar_cfg_y
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

	if gui_tooltip.id != '' {
		if cfg.tooltip != unsafe { nil } {
			if cfg.tooltip.id == gui_tooltip.id {
				extra_content << tooltip(cfg.tooltip)
			}
		}
	}

	content := match extra_content.len > 0 {
		true { arrays.append(cfg.content, extra_content) }
		else { cfg.content }
	}

	view := ContainerView{
		id:             cfg.id
		id_focus:       cfg.id_focus
		axis:           cfg.axis
		name:           cfg.name
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
		over_draw:      cfg.over_draw
		scroll_mode:    cfg.scroll_mode
		float:          cfg.float
		float_anchor:   cfg.float_anchor
		float_tie_off:  cfg.float_tie_off
		float_offset_x: cfg.float_offset_x
		float_offset_y: cfg.float_offset_y
		tooltip:        cfg.tooltip
		on_click:       if cfg.on_any_click != unsafe { nil } {
			cfg.on_any_click
		} else {
			cfg.left_click()
		}
		on_char:        cfg.on_char
		on_keydown:     cfg.on_keydown
		on_mouse_move:  cfg.on_mouse_move
		on_mouse_up:    cfg.on_mouse_up
		on_hover:       cfg.on_hover
		amend_layout:   cfg.amend_layout
		content:        content
	}
	return view
}

// --- Common layout containers ---

// column arranges its content top to bottom. The gap between child items is
// determined by the spacing parameter. See [ContainerCfg](#ContainerCfg)
pub fn column(cfg ContainerCfg) View {
	unsafe { // avoid allocating struct
		cfg.axis = .top_to_bottom
		cfg.name = if cfg.name.is_blank() { 'column' } else { cfg.name }
	}
	return container(cfg)
}

// row arranges its content left to right. The gap between child items is
// determined by the spacing parameter. See [ContainerCfg](#ContainerCfg)
pub fn row(cfg ContainerCfg) View {
	unsafe { // avoid allocating struct
		cfg.axis = .left_to_right
		cfg.name = if cfg.name.is_blank() { 'row' } else { cfg.name }
	}
	return container(cfg)
}

// canvas does not arrange or otherwise layout its content. See [ContainerCfg](#ContainerCfg)
pub fn canvas(cfg ContainerCfg) View {
	unsafe { // avoid allocating struct
		cfg.name = if cfg.name.is_blank() { 'canvas' } else { cfg.name }
	}
	return container(cfg)
}

pub fn circle(cfg ContainerCfg) View {
	unsafe { // avoid allocating struct
		cfg.name = if cfg.name.is_blank() { 'circle' } else { cfg.name }
	}
	mut circle := container(cfg) as ContainerView
	circle.shape_type = .circle
	return circle
}

fn (cv &ContainerView) on_mouse_move_tooltip(shape &Shape, mut _ Event, mut w Window) {
	if cv.tooltip != unsafe { nil } {
		if cv.tooltip.content.len > 0 {
			w.animation_add(mut cv.tooltip.animation_tooltip())
			gui_tooltip.bounds = DrawClip{
				x:      shape.x
				y:      shape.y
				width:  shape.width
				height: shape.height
			}
		}
	}
}

fn (cfg &ContainerCfg) left_click() fn (&Layout, mut Event, mut Window) {
	if cfg.on_click == unsafe { nil } {
		return cfg.on_click
	}
	on_click := cfg.on_click
	return fn [on_click] (layout &Layout, mut e Event, mut w Window) {
		if e.mouse_button == .left {
			on_click(layout, mut e, mut w)
		}
	}
}

fn invisible_container_view() ContainerView {
	return ContainerView{
		disabled:  true
		over_draw: true // removes it from spacing calculations
		padding:   padding_none
	}
}
