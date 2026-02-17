module svg

// Tessellation and stroke constants
const stroke_cross_tolerance = f32(0.001) // tolerance for detecting straight joins
const stroke_miter_limit = f32(4.0) // SVG default miter limit multiplier
const stroke_round_cap_segments = 8 // segments for round cap semicircle
const curve_degenerate_threshold = f32(0.0001) // threshold for degenerate curves
const closed_path_epsilon = f32(0.0001) // tolerance for closed path detection

// PathCmd defines the type of drawing command in a path segment.
pub enum PathCmd as u8 {
	move_to  // 2 floats: x, y
	line_to  // 2 floats: x, y
	quad_to  // 4 floats: cx, cy, x, y
	cubic_to // 6 floats: c1x, c1y, c2x, c2y, x, y
	close    // 0 floats
}

// PathSegment represents a single command in a vector path.
pub struct PathSegment {
pub:
	cmd    PathCmd
	points []f32
}

// StrokeCap defines line cap styles.
pub enum StrokeCap as u8 {
	butt
	round
	square
	inherit // sentinel: use inherited value
}

// StrokeJoin defines line join styles.
pub enum StrokeJoin as u8 {
	miter
	round
	bevel
	inherit // sentinel: use inherited value
}

// SvgGradientStop holds one color stop in a linear gradient.
pub struct SvgGradientStop {
pub:
	offset f32
	color  SvgColor
}

// SvgGradientDef holds a parsed <linearGradient> definition.
pub struct SvgGradientDef {
pub:
	x1                  f32
	y1                  f32
	x2                  f32
	y2                  f32
	stops               []SvgGradientStop
	object_bounding_box bool // true = gradientUnits="objectBoundingBox"
}

// SvgText holds a parsed <text> element for deferred rendering.
pub struct SvgText {
pub:
	text             string
	x                f32
	y                f32 // baseline y in viewBox coords
	font_family      string
	font_size        f32 // viewBox units (pre-transform-scaled)
	bold             bool
	italic           bool
	color            SvgColor
	anchor           u8 // 0=start, 1=middle, 2=end
	opacity          f32 = 1.0
	underline        bool
	strikethrough    bool
	filter_id        string
	fill_gradient_id string
	letter_spacing   f32
	stroke_color     SvgColor = color_transparent
	stroke_width     f32
}

// SvgTextPath holds a parsed <textPath> for text-on-curve.
pub struct SvgTextPath {
pub:
	text             string
	path_id          string
	start_offset     f32
	is_percent       bool
	anchor           u8
	spacing          u8
	method           u8
	side             u8
	font_family      string
	font_size        f32
	bold             bool
	italic           bool
	color            SvgColor
	opacity          f32 = 1.0
	filter_id        string
	fill_gradient_id string
	letter_spacing   f32
	stroke_color     SvgColor = color_transparent
	stroke_width     f32
}

// SvgFilter holds a parsed <filter> definition.
pub struct SvgFilter {
pub:
	id          string
	std_dev     f32
	blur_layers int = 1 // feMerge blur node count
	keep_source bool // feMerge includes SourceGraphic
}

// SvgFilteredGroup holds paths/texts belonging to a filtered <g>.
pub struct SvgFilteredGroup {
pub:
	filter_id  string
	paths      []VectorPath
	texts      []SvgText
	text_paths []SvgTextPath
}

// VectorPath represents a single filled path with color.
pub struct VectorPath {
pub mut:
	segments           []PathSegment
	fill_color         SvgColor   = color_inherit
	transform          [6]f32     = [f32(1), 0, 0, 1, 0, 0]! // identity: [a,b,c,d,e,f]
	stroke_color       SvgColor   = color_inherit
	stroke_width       f32        = -1.0 // negative = inherit from parent
	stroke_cap         StrokeCap  = .inherit
	stroke_join        StrokeJoin = .inherit
	clip_path_id       string // references clip_paths key, empty = none
	fill_gradient_id   string // references gradients key, empty = flat fill
	stroke_gradient_id string // references gradients key
	filter_id          string // references filters key, empty = none
	stroke_dasharray   []f32  // dash/gap pattern in SVG units
	opacity            f32 = 1.0
	fill_opacity       f32 = 1.0
	stroke_opacity     f32 = 1.0
}

// VectorGraphic holds the complete parsed vector graphic (e.g., from SVG).
pub struct VectorGraphic {
pub mut:
	width           f32 // viewBox width
	height          f32 // viewBox height
	view_box_x      f32 // viewBox min-x offset
	view_box_y      f32 // viewBox min-y offset
	paths           []VectorPath
	texts           []SvgText
	text_paths      []SvgTextPath
	defs_paths      map[string]string         // id -> raw d attribute
	clip_paths      map[string][]VectorPath   // id -> clip geometry
	gradients       map[string]SvgGradientDef // id -> gradient def
	filters         map[string]SvgFilter
	filtered_groups []SvgFilteredGroup
}

// TessellatedPath holds triangulated geometry ready for rendering.
pub struct TessellatedPath {
pub:
	triangles     []f32 // x,y pairs forming triangles
	color         SvgColor
	vertex_colors []SvgColor // per-vertex colors (len = triangles.len/2); empty = flat color
	is_clip_mask  bool       // true = stencil-write geometry
	clip_group    int        // groups clip mask + clipped content (0 = none)
}
