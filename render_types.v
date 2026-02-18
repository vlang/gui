module gui

import gg
import sokol.gfx
import vglyph

// A Renderer is the final computed drawing instruction. gui.Window keeps an array
// of Renderers and only uses that array to paint the window. The window can be
// repainted many times before the a new view state is generated.

const password_char = '*'

struct DrawCircle {
	color  gg.Color
	x      f32
	y      f32
	radius f32
	fill   bool
}

struct DrawImage {
	img &gg.Image
	x   f32
	y   f32
	w   f32
	h   f32
}

struct DrawLine {
	cfg gg.PenConfig
	x   f32
	y   f32
	x1  f32
	y1  f32
}

struct DrawNone {}

struct DrawText {
	text string
	cfg  vglyph.TextConfig
	x    f32
	y    f32
}

// DrawShadow represents a deferred command to draw a drop shadow.
// This is required to ensure shadows are drawn in the correct order during the render pass.
struct DrawShadow {
	x           f32
	y           f32
	width       f32
	height      f32
	radius      f32
	blur_radius f32
	color       gg.Color
	offset_x    f32
	offset_y    f32
}

struct DrawStrokeRect {
	x         f32
	y         f32
	w         f32
	h         f32
	radius    f32
	color     gg.Color
	thickness f32
}

struct DrawBlur {
	x           f32
	y           f32
	width       f32
	height      f32
	radius      f32
	blur_radius f32
	color       gg.Color
}

struct DrawGradientBorder {
	x         f32
	y         f32
	w         f32
	h         f32
	radius    f32
	thickness f32
	gradient  &Gradient
}

struct DrawGradient {
	x        f32
	y        f32
	w        f32
	h        f32
	radius   f32
	gradient &Gradient
}

struct DrawCustomShader {
	x      f32
	y      f32
	w      f32
	h      f32
	radius f32
	color  gg.Color
	shader &Shader
}

struct DrawSvg {
	triangles     []f32 // x,y pairs forming triangles
	color         gg.Color
	vertex_colors []gg.Color // per-vertex colors; empty = flat color
	x             f32
	y             f32
	scale         f32
	is_clip_mask  bool // stencil-write geometry
	clip_group    int  // non-zero = uses stencil clipping
}

// DrawFilterBegin marks the start of a filtered SVG group.
struct DrawFilterBegin {
	group_idx int // index into CachedSvg.filtered_groups
	x         f32
	y         f32
	scale     f32
	cached    &CachedSvg = unsafe { nil }
}

// DrawFilterEnd marks the end of a filtered SVG group.
struct DrawFilterEnd {}

// DrawFilterComposite draws a blurred texture as a textured quad.
struct DrawFilterComposite {
	texture gfx.Image
	sampler gfx.Sampler
	x       f32
	y       f32
	width   f32
	height  f32
	layers  int // draw blur texture this many times (glow intensity)
}

struct DrawLayout {
	layout   &vglyph.Layout
	x        f32
	y        f32
	gradient &vglyph.GradientConfig = unsafe { nil }
}

struct DrawLayoutTransformed {
	layout    &vglyph.Layout
	x         f32
	y         f32
	transform vglyph.AffineTransform
	gradient  &vglyph.GradientConfig = unsafe { nil }
}

struct DrawLayoutPlaced {
	// `layout` must outlive render dispatch.
	// Do not store pointers to stack-local layouts here.
	layout     &vglyph.Layout
	placements []vglyph.GlyphPlacement
}

type DrawClip = gg.Rect
type DrawRect = gg.DrawRectParams
type Renderer = DrawCircle
	| DrawClip
	| DrawImage
	| DrawLayout
	| DrawLayoutTransformed
	| DrawLayoutPlaced
	| DrawLine
	| DrawNone
	| DrawRect
	| DrawStrokeRect
	| DrawSvg
	| DrawText
	| DrawShadow
	| DrawBlur
	| DrawGradient
	| DrawGradientBorder
	| DrawCustomShader
	| DrawFilterBegin
	| DrawFilterEnd
	| DrawFilterComposite

struct DrawTextSelectionParams {
	shape    &Shape
	line     vglyph.Line
	draw_x   f32
	draw_y   f32
	byte_beg int
	byte_end int
	text_cfg vglyph.TextConfig
}
