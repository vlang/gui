module gui

// The `shaders.v` module provides high-performance rendering primitives for

// rounded rectangles, using signed distance field (SDF) shaders via gg.render.
// This replaces the previous discrete triangle implementation.
//
// Motivation for Signed Distance Fields (SDF):
// 1. Infinite Resolution: SDFs are mathematical descriptions of shapes. They remain
//    crisp at any zoom level or scale, unlike texture-based rounded corners which pixelate.
// 2. Anti-aliasing: The distance value allows for perfect, mathematically calculated
//    anti-aliasing at the shape's edge, handled entirely in the fragment shader.
// 3. Batching: By packing parameters (radius, thickness) into vertex attributes,
//    multiple rounded rectangles with different properties can be drawn in a single
//    draw call (if sgl supports it), or at least without switching shaders/uniforms
//    frequently.
// 4. Flexibility: A single quad can represent a filled rect, a bordered rect, or
//    a complex shadow, just by changing the SDF math in the shader.
import gg
import gg.render
import log
import sokol.gfx
import math

// SvgFilterState holds GPU resources for offscreen SVG filter rendering.
// Blur/content pipelines use raw gfx (not SGL) to avoid SGL vertex
// buffer issues with offscreen passes. The composite pipeline stays
// SGL since it draws on the swapchain during the normal frame.
struct SvgFilterState {
mut:
	tex_a            gfx.Image
	tex_b            gfx.Image
	depth            gfx.Image
	att_a            gfx.Attachments
	att_b            gfx.Attachments
	sampler          gfx.Sampler
	tex_width        int
	tex_height       int
	blur_h_pip       gfx.Pipeline    // raw gfx: horizontal blur
	blur_v_pip       gfx.Pipeline    // raw gfx: vertical blur
	content_pip      gfx.Pipeline    // raw gfx: colored triangles
	texture_quad_pip render.Pipeline // gg.render: composite to swapchain
	quad_vbuf        gfx.Buffer      // static unit quad (blur passes)
	content_vbuf     gfx.Buffer      // dynamic buffer for SVG content
	content_vbuf_sz  int             // current content buffer capacity
	scratch_vertices []FilterVertex
	initialized      bool
}

// Pipelines holds lazily-initialized GPU rendering pipelines.
// Each pipeline is considered initialized when its `.id != 0`.
struct Pipelines {
mut:
	rounded_rect               render.Pipeline
	shadow                     render.Pipeline
	blur                       render.Pipeline
	gradient                   render.Pipeline
	image_clip                 render.Pipeline
	image_clip_init_failed     bool
	image_clip_fallback_warned bool
	stencil_write              render.Pipeline
	stencil_test               render.Pipeline
	stencil_clear              render.Pipeline
	custom                     map[u64]render.Pipeline
	gradient_stop_warned       bool
}

const packed_param_stride = 4096
const packed_param_scale = 4
const packed_param_mask = packed_param_stride - 1
const fallback_max_filter_image_size = 4096

// pack_shader_params packs radius and thickness into one f32.
// Both values are clamped, quantized to quarter-pixel precision,
// and packed as two 12-bit integers.
@[inline]
fn pack_shader_params(radius f32, thickness f32) f32 {
	max_value := f32(packed_param_mask) / f32(packed_param_scale)
	safe_radius := math.max(0.0, math.min(radius, max_value))
	safe_thickness := math.max(0.0, math.min(thickness, max_value))
	radius_q := int(math.round(f64(safe_radius * f32(packed_param_scale))))
	thickness_q := int(math.round(f64(safe_thickness * f32(packed_param_scale))))
	return f32(radius_q * packed_param_stride + thickness_q)
}

@[inline]
fn filter_max_image_size() int {
	limits := gfx.query_limits()
	if limits.max_image_size_2d > 0 {
		return limits.max_image_size_2d
	}
	return fallback_max_filter_image_size
}

fn gui_builtin_vertex_layout() gfx.VertexLayoutState {
	mut attrs := [16]gfx.VertexAttrDesc{}
	attrs[0] = gfx.VertexAttrDesc{
		format:       .float3
		offset:       0
		buffer_index: 0
	}
	attrs[1] = gfx.VertexAttrDesc{
		format:       .float2
		offset:       12
		buffer_index: 0
	}
	attrs[2] = gfx.VertexAttrDesc{
		format:       .ubyte4n
		offset:       20
		buffer_index: 0
	}
	mut buffers := [8]gfx.VertexBufferLayoutState{}
	buffers[0] = gfx.VertexBufferLayoutState{
		stride: 24
	}
	return gfx.VertexLayoutState{
		attrs:   attrs
		buffers: buffers
	}
}

fn gui_builtin_alpha_colors() [4]gfx.ColorTargetState {
	mut colors := [4]gfx.ColorTargetState{}
	colors[0] = gfx.ColorTargetState{
		blend:      gfx.BlendState{
			enabled:          true
			src_factor_rgb:   .src_alpha
			dst_factor_rgb:   .one_minus_src_alpha
			src_factor_alpha: .one
			dst_factor_alpha: .one_minus_src_alpha
		}
		write_mask: .rgba
	}
	return colors
}

fn make_gui_builtin_render_pipeline(r &render.Context, label &char, shader gfx.Shader) render.Pipeline {
	desc := gfx.PipelineDesc{
		label:  unsafe { label }
		colors: gui_builtin_alpha_colors()
	}
	return r.make_pipeline_with_shader(desc, shader)
}

fn make_gui_builtin_gfx_pipeline(label &char, shader gfx.Shader) gfx.Pipeline {
	return gfx.make_pipeline(&gfx.PipelineDesc{
		label:  unsafe { label }
		colors: gui_builtin_alpha_colors()
		layout: gui_builtin_vertex_layout()
		shader: shader
	})
}

fn init_rounded_rect_pipeline(mut window Window) bool {
	if window.pip.rounded_rect.id != 0 {
		return true
	}
	window.pip.rounded_rect = make_gui_builtin_render_pipeline(window.ui.r, c'rounded_rect_pip',
		gfx.make_shader(voidptr(C.gui_rounded_rect_shader_desc(gfx.query_backend()))))
	return window.pip.rounded_rect.id != 0
}

// init_shadow_pipeline initializes the generated built-in pipeline for rendering drop shadows.
// The shader implements a Gaussian-like blur approximation using Signed Distance Fields (SDF).
fn init_shadow_pipeline(mut window Window) {
	if window.pip.shadow.id != 0 {
		return
	}
	window.pip.shadow = make_gui_builtin_render_pipeline(window.ui.r, c'shadow_pip',
		gfx.make_shader(voidptr(C.gui_shadow_shader_desc(gfx.query_backend()))))
}

// init_blur_pipeline initializes the pipeline for a standalone Gaussian blur effect.
// It shares the same vertex attributes as the shadow pipeline but uses a specific
// fragment shader intended for blurring content without the complexities of the drop-shadow offset logic.
fn init_blur_pipeline(mut window Window) {
	if window.pip.blur.id != 0 {
		return
	}
	window.pip.blur = make_gui_builtin_render_pipeline(window.ui.r, c'blur_pip',
		gfx.make_shader(voidptr(C.gui_blur_shader_desc(gfx.query_backend()))))
}

// init_gradient_pipeline initializes the generated built-in pipeline for multi-stop gradient rendering.
// Gradient stop data is packed into the tm uniform matrix.
fn init_gradient_pipeline(mut window Window) {
	if window.pip.gradient.id != 0 {
		return
	}
	window.pip.gradient = make_gui_builtin_render_pipeline(window.ui.r, c'gradient_pip',
		gfx.make_shader(voidptr(C.gui_gradient_shader_desc(gfx.query_backend()))))
}

// draw_shadow_rect draws a rounded rectangle drop shadow.
// x, y, w, h specifies the bounding box of the *casting element* (not the shadow itself).
// The shadow geometry is automatically expanded based on the blur radius.
// The shadow is rendered as a "hollow" rim shadow (fading out from the edge in both directions),
// ensuring correct appearance for both filled and transparent containers.
// radius: The corner radius of the casting element.
// blur: The blur radius (standard deviation approximation).
//
// Shadow Logic:
// The shader computes the transparency based on the distance from the rounded rectangle edge.
// It combines a Gaussian-like falloff (for the blur) with a hard clip against the
// casting element's shape (passed via direct offset calculation) to specificy where the shadow starts.
pub fn draw_shadow_rect(x f32, y f32, w f32, h f32, radius f32, blur f32, c gg.Color, offset_x f32, offset_y f32, mut window Window) {
	if c.a == 0 {
		return
	}

	scale := window.ui.scale
	// We draw a larger quad to accommodate the blur
	// Padding = blur radius * 1.5 to be safe
	blur_pad := blur * 1.5

	sx := (x - blur_pad) * scale
	sy := (y - blur_pad) * scale
	sw := (w + blur_pad * 2) * scale
	sh := (h + blur_pad * 2) * scale

	r := radius * scale
	b := blur * scale

	ox := offset_x * scale
	oy := offset_y * scale

	init_shadow_pipeline(mut window)

	// Pass offset via Texture Matrix
	window.ui.r.matrix_mode_texture()
	window.ui.r.push_matrix()
	window.ui.r.load_identity()
	// Translate by the NEGATIVE offset because the "clip box" needs to be shifted
	// relative to the shadow.
	// The shadow is drawn at (x,y) which INCLUDES the offset.
	// The casting box is at (x - offset_x, y - offset_y).
	// So the coordinate system must be shifted so that (0,0) aligns correctly.
	// sgl doesn't have a generic "set uniform" for custom uniforms easily accessible here without breaking abstraction.
	// The Translation part of the matrix is used to pass this data.

	window.ui.r.translate(ox, oy, 0.0)

	window.ui.r.load_pipeline(window.pip.shadow)
	window.ui.r.c4b(c.r, c.g, c.b, c.a)

	// Pack radius and blur using the fixed-point packer.
	z_val := pack_shader_params(r, b)

	draw_quad(window.ui.r, sx, sy, sw, sh, z_val)
	window.ui.r.load_default_pipeline()
	window.ui.r.c4b(255, 255, 255, 255) // Reset color state

	window.ui.r.pop_matrix()
	window.ui.r.matrix_mode_modelview()
}

// draw_rounded_rect_filled draws a solid rounded rectangle using SDF shading.
// The shape is mathematically defined in the fragment shader, allowing for infinite resolution
// and perfect anti-aliasing.
pub fn draw_rounded_rect_filled(x f32, y f32, w f32, h f32, radius f32, c gg.Color, mut window Window) {
	if w <= 0 || h <= 0 {
		return
	}

	scale := window.ui.scale
	sx := x * scale
	sy := y * scale
	sw := w * scale
	sh := h * scale
	mut r := radius * scale

	// Clamp radius
	min_dim := if sw < sh { sw } else { sh }
	if r > min_dim / 2.0 {
		r = min_dim / 2.0
	}
	if r < 0 {
		r = 0
	}

	if !init_rounded_rect_pipeline(mut window) {
		return
	}

	window.ui.r.load_pipeline(window.pip.rounded_rect)
	window.ui.r.c4b(c.r, c.g, c.b, c.a)

	z_val := pack_shader_params(r, 0)

	draw_quad(window.ui.r, sx, sy, sw, sh, z_val)
	window.ui.r.load_default_pipeline()
}

// draw_rounded_rect_empty draws a bordered (stroked) rounded rectangle.
// It uses the same SDF logic as the filled rect but subtracts an inner shape
// based on the thickness parameter to create the border.
pub fn draw_rounded_rect_empty(x f32, y f32, w f32, h f32, radius f32, thickness f32, c gg.Color, mut window Window) {
	if w <= 0 || h <= 0 {
		return
	}

	scale := window.ui.scale
	sx := x * scale
	sy := y * scale
	sw := w * scale
	sh := h * scale
	mut r := radius * scale

	min_dim := if sw < sh { sw } else { sh }
	if r > min_dim / 2.0 {
		r = min_dim / 2.0
	}
	if r < 0 {
		r = 0
	}

	if !init_rounded_rect_pipeline(mut window) {
		return
	}

	window.ui.r.load_pipeline(window.pip.rounded_rect)
	window.ui.r.c4b(c.r, c.g, c.b, c.a)

	// Pack radius and stroke thickness.
	z_val := pack_shader_params(r, thickness * scale)

	draw_quad(window.ui.r, sx, sy, sw, sh, z_val)
	window.ui.r.load_default_pipeline()
}

// init_stencil_pipelines creates renderer pipelines for clipPath
// stencil clipping:
//   stencil_write_pip: writes 1 to stencil, no color output
//   stencil_test_pip:  draws only where stencil == 1
fn init_stencil_pipelines(mut window Window) {
	if window.pip.stencil_write.id == 0 {
		// Stencil write: always pass, replace with ref=1,
		// disable color writes.
		mut colors_w := [4]gfx.ColorTargetState{}
		colors_w[0] = gfx.ColorTargetState{
			write_mask: .none
		}
		desc_w := gfx.PipelineDesc{
			label:   c'stencil_write_pip'
			colors:  colors_w
			stencil: gfx.StencilState{
				enabled:    true
				front:      gfx.StencilFaceState{
					compare:       .always
					pass_op:       .replace
					fail_op:       .keep
					depth_fail_op: .keep
				}
				back:       gfx.StencilFaceState{
					compare:       .always
					pass_op:       .replace
					fail_op:       .keep
					depth_fail_op: .keep
				}
				read_mask:  0xFF
				write_mask: 0xFF
				ref:        1
			}
		}
		window.pip.stencil_write = window.ui.r.make_pipeline(desc_w)
	}

	if window.pip.stencil_test.id == 0 {
		// Stencil test: draw only where stencil == ref(1),
		// normal alpha blending.
		mut colors_t := [4]gfx.ColorTargetState{}
		colors_t[0] = gfx.ColorTargetState{
			blend:      gfx.BlendState{
				enabled:          true
				src_factor_rgb:   .src_alpha
				dst_factor_rgb:   .one_minus_src_alpha
				src_factor_alpha: .one
				dst_factor_alpha: .one_minus_src_alpha
			}
			write_mask: .rgba
		}
		desc_t := gfx.PipelineDesc{
			label:   c'stencil_test_pip'
			colors:  colors_t
			stencil: gfx.StencilState{
				enabled:    true
				front:      gfx.StencilFaceState{
					compare:       .equal
					pass_op:       .keep
					fail_op:       .keep
					depth_fail_op: .keep
				}
				back:       gfx.StencilFaceState{
					compare:       .equal
					pass_op:       .keep
					fail_op:       .keep
					depth_fail_op: .keep
				}
				read_mask:  0xFF
				write_mask: 0x00
				ref:        1
			}
		}
		window.pip.stencil_test = window.ui.r.make_pipeline(desc_t)
	}

	if window.pip.stencil_clear.id == 0 {
		// Stencil clear: write ref=0 to reset stencil bits,
		// no color output.
		mut colors_c := [4]gfx.ColorTargetState{}
		colors_c[0] = gfx.ColorTargetState{
			write_mask: .none
		}
		desc_c := gfx.PipelineDesc{
			label:   c'stencil_clear_pip'
			colors:  colors_c
			stencil: gfx.StencilState{
				enabled:    true
				front:      gfx.StencilFaceState{
					compare:       .always
					pass_op:       .replace
					fail_op:       .keep
					depth_fail_op: .keep
				}
				back:       gfx.StencilFaceState{
					compare:       .always
					pass_op:       .replace
					fail_op:       .keep
					depth_fail_op: .keep
				}
				read_mask:  0xFF
				write_mask: 0xFF
				ref:        0
			}
		}
		window.pip.stencil_clear = window.ui.r.make_pipeline(desc_c)
	}
}

// init_custom_pipeline creates and caches a pipeline for a custom
// fragment shader. Pipelines are keyed by source hash so identical
// shader bodies share a single compiled pipeline.
fn init_custom_pipeline(shader &Shader, mut window Window) render.Pipeline {
	key := shader_hash(shader)
	if pip := window.pip.custom[key] {
		return pip
	}
	$if windows && sokol_d3d11 ? {
		log.warn('custom GLSL/Metal shaders are not supported with -d sokol_d3d11; using rounded-rect fallback')
		pip := render.Pipeline{}
		window.pip.custom[key] = pip
		return pip
	}

	mut attrs := [16]gfx.VertexAttrDesc{}
	attrs[0] = gfx.VertexAttrDesc{
		format:       .float3
		offset:       0
		buffer_index: 0
	}
	attrs[1] = gfx.VertexAttrDesc{
		format:       .float2
		offset:       12
		buffer_index: 0
	}
	attrs[2] = gfx.VertexAttrDesc{
		format:       .ubyte4n
		offset:       20
		buffer_index: 0
	}

	mut buffers := [8]gfx.VertexBufferLayoutState{}
	buffers[0] = gfx.VertexBufferLayoutState{
		stride: 24
	}

	mut shader_attrs := [16]gfx.ShaderAttrDesc{}
	shader_attrs[0] = gfx.ShaderAttrDesc{
		name:      c'position'
		sem_name:  c'POSITION'
		sem_index: 0
	}
	shader_attrs[1] = gfx.ShaderAttrDesc{
		name:      c'texcoord0'
		sem_name:  c'TEXCOORD'
		sem_index: 0
	}
	shader_attrs[2] = gfx.ShaderAttrDesc{
		name:      c'color0'
		sem_name:  c'COLOR'
		sem_index: 0
	}

	mut ub_uniforms := [16]gfx.ShaderUniformDesc{}
	ub_uniforms[0] = gfx.ShaderUniformDesc{
		name:        c'mvp'
		@type:       .mat4
		array_count: 1
	}
	ub_uniforms[1] = gfx.ShaderUniformDesc{
		name:        c'tm'
		@type:       .mat4
		array_count: 1
	}

	mut ub := [4]gfx.ShaderUniformBlockDesc{}
	ub[0] = gfx.ShaderUniformBlockDesc{
		size:     128
		uniforms: ub_uniforms
	}

	mut colors := [4]gfx.ColorTargetState{}
	colors[0] = gfx.ColorTargetState{
		blend:      gfx.BlendState{
			enabled:          true
			src_factor_rgb:   .src_alpha
			dst_factor_rgb:   .one_minus_src_alpha
			src_factor_alpha: .one
			dst_factor_alpha: .one_minus_src_alpha
		}
		write_mask: .rgba
	}

	mut shader_images := [12]gfx.ShaderImageDesc{}
	shader_images[0] = gfx.ShaderImageDesc{
		used:        true
		image_type:  ._2d
		sample_type: .float
	}

	mut shader_samplers := [8]gfx.ShaderSamplerDesc{}
	shader_samplers[0] = gfx.ShaderSamplerDesc{
		used:         true
		sampler_type: .filtering
	}

	mut shader_image_sampler_pairs := [12]gfx.ShaderImageSamplerPairDesc{}
	shader_image_sampler_pairs[0] = gfx.ShaderImageSamplerPairDesc{
		used:         true
		image_slot:   0
		sampler_slot: 0
		glsl_name:    c'tex'
	}

	mut shader_desc := gfx.ShaderDesc{
		attrs: shader_attrs
	}

	$if macos {
		fs_source := build_metal_fragment(shader.metal)
		shader_desc.vs = gfx.ShaderStageDesc{
			source:         vs_custom_metal.str
			entry:          c'vs_main'
			uniform_blocks: ub
		}
		shader_desc.fs = gfx.ShaderStageDesc{
			source:              fs_source.str
			entry:               c'fs_main'
			images:              shader_images
			samplers:            shader_samplers
			image_sampler_pairs: shader_image_sampler_pairs
		}
	} $else {
		fs_source := build_glsl_fragment(shader.glsl)
		shader_desc.vs = gfx.ShaderStageDesc{
			source:         vs_custom_glsl.str
			uniform_blocks: ub
		}
		shader_desc.fs = gfx.ShaderStageDesc{
			source:              fs_source.str
			images:              shader_images
			samplers:            shader_samplers
			image_sampler_pairs: shader_image_sampler_pairs
		}
	}

	desc := gfx.PipelineDesc{
		label:  c'custom_shader_pip'
		colors: colors
		layout: gfx.VertexLayoutState{
			attrs:   attrs
			buffers: buffers
		}
		shader: gfx.make_shader(&shader_desc)
	}

	pip := window.ui.r.make_pipeline_with_shader(desc, desc.shader)
	window.pip.custom[key] = pip
	return pip
}

// draw_custom_shader_rect draws a rounded rectangle filled by a
// custom fragment shader. User params are loaded into the tm matrix.
pub fn draw_custom_shader_rect(x f32, y f32, w f32, h f32, radius f32, c gg.Color, shader &Shader, mut window Window) {
	if w <= 0 || h <= 0 {
		return
	}

	scale := window.ui.scale
	sx := x * scale
	sy := y * scale
	sw := w * scale
	sh := h * scale
	mut r := radius * scale

	min_dim := if sw < sh { sw } else { sh }
	if r > min_dim / 2.0 {
		r = min_dim / 2.0
	}
	if r < 0 {
		r = 0
	}

	pip := init_custom_pipeline(shader, mut window)
	if pip.id == 0 {
		$if windows && sokol_d3d11 ? {
			draw_rounded_rect_filled(x, y, w, h, radius, c, mut window)
		}
		return
	}

	// Load user params into tm matrix
	window.ui.r.matrix_mode_texture()
	window.ui.r.push_matrix()

	mut tm_data := [16]f32{}
	max_params := if shader.params.len > 16 { 16 } else { shader.params.len }
	for i in 0 .. max_params {
		tm_data[i] = shader.params[i]
	}
	window.ui.r.load_matrix(tm_data[0..])

	window.ui.r.load_pipeline(pip)
	window.ui.r.c4b(c.r, c.g, c.b, c.a)

	z_val := pack_shader_params(r, 0)
	draw_quad(window.ui.r, sx, sy, sw, sh, z_val)

	window.ui.r.load_default_pipeline()
	window.ui.r.c4b(255, 255, 255, 255)
	window.ui.r.pop_matrix()
	window.ui.r.matrix_mode_modelview()
}

// FilterVertex matches the SGL vertex layout (24 bytes):
// position(float3) + texcoord(float2) + color(ubyte4n).
struct FilterVertex {
	x f32
	y f32
	z f32
	u f32
	v f32
	r u8
	g u8
	b u8
	a u8
}

// ortho_column_major builds an orthographic projection matrix
// in column-major order (Metal/GL convention).
fn ortho_column_major(l f32, r f32, b f32, t f32, n f32, f f32) [16]f32 {
	mut m := [16]f32{}
	m[0] = 2.0 / (r - l)
	m[5] = 2.0 / (t - b)
	m[10] = -2.0 / (f - n)
	m[12] = -(r + l) / (r - l)
	m[13] = -(t + b) / (t - b)
	m[14] = -(f + n) / (f - n)
	m[15] = 1.0
	return m
}

// make_filter_gfx_pipeline creates a raw gfx.Pipeline for offscreen
// rendering using the generated built-in shader descriptors.
fn make_filter_gfx_pipeline(label &char, shader gfx.Shader) gfx.Pipeline {
	return make_gui_builtin_gfx_pipeline(label, shader)
}

// ensure_filter_state lazily initializes offscreen filter resources.
fn ensure_filter_state(mut window Window) {
	if window.filter_state.initialized {
		return
	}

	window.filter_state.sampler = gfx.make_sampler(gfx.SamplerDesc{
		min_filter: .linear
		mag_filter: .linear
		wrap_u:     .clamp_to_edge
		wrap_v:     .clamp_to_edge
		label:      c'filter_sampler'
	})

	// Blur/content pipelines: raw gfx (offscreen passes)
	window.filter_state.blur_h_pip = make_filter_gfx_pipeline(c'filter_blur_h_pip',
		gfx.make_shader(voidptr(C.gui_filter_blur_h_shader_desc(gfx.query_backend()))))
	window.filter_state.blur_v_pip = make_filter_gfx_pipeline(c'filter_blur_v_pip',
		gfx.make_shader(voidptr(C.gui_filter_blur_v_shader_desc(gfx.query_backend()))))
	window.filter_state.content_pip = make_filter_gfx_pipeline(c'filter_content_pip',
		gfx.make_shader(voidptr(C.gui_filter_color_shader_desc(gfx.query_backend()))))

	// Composite pipeline: SGL (swapchain pass)
	window.filter_state.texture_quad_pip = make_gui_builtin_render_pipeline(window.ui.r, c'filter_texture_pip',
		gfx.make_shader(voidptr(C.gui_filter_texture_shader_desc(gfx.query_backend()))))

	// Static unit quad for blur fullscreen passes (6 vertices)
	quad_verts := [
		FilterVertex{0, 0, 0, 0, 0, 255, 255, 255, 255},
		FilterVertex{1, 0, 0, 1, 0, 255, 255, 255, 255},
		FilterVertex{1, 1, 0, 1, 1, 255, 255, 255, 255},
		FilterVertex{0, 0, 0, 0, 0, 255, 255, 255, 255},
		FilterVertex{1, 1, 0, 1, 1, 255, 255, 255, 255},
		FilterVertex{0, 1, 0, 0, 1, 255, 255, 255, 255},
	]!
	window.filter_state.quad_vbuf = gfx.make_buffer(gfx.BufferDesc{
		data:  gfx.Range{
			ptr:  unsafe { &quad_verts[0] }
			size: usize(sizeof(FilterVertex) * 6)
		}
		label: c'filter_quad_vbuf'
	})

	window.filter_state.initialized = true
}

// ensure_filter_textures creates or resizes offscreen render targets.
// Uses swapchain pixel format so SGL default pipeline works unchanged.
fn ensure_filter_textures(mut window Window, width int, height int) bool {
	max_size := filter_max_image_size()
	w := if width < 1 { 1 } else { width }
	h := if height < 1 { 1 } else { height }
	if w > max_size || h > max_size {
		return false
	}

	if window.filter_state.tex_width == w && window.filter_state.tex_height == h {
		return true
	}

	// Destroy old resources if resizing
	if window.filter_state.tex_width > 0 {
		gfx.destroy_image(window.filter_state.tex_a)
		gfx.destroy_image(window.filter_state.tex_b)
		gfx.destroy_image(window.filter_state.depth)
		gfx.destroy_attachments(window.filter_state.att_a)
		gfx.destroy_attachments(window.filter_state.att_b)
	}

	formats := gui_render_target_formats()

	img_desc := gfx.ImageDesc{
		render_target: true
		width:         w
		height:        h
		pixel_format:  formats.color
		label:         c'filter_tex'
	}
	tex_a := gfx.make_image(&img_desc)
	tex_b := gfx.make_image(&img_desc)

	// Shared depth buffer (required by default SGL pipeline)
	depth := gfx.make_image(gfx.ImageDesc{
		render_target: true
		width:         w
		height:        h
		pixel_format:  formats.depth
		label:         c'filter_depth'
	})
	if tex_a.id == 0 || tex_b.id == 0 || depth.id == 0 {
		if tex_a.id != 0 {
			gfx.destroy_image(tex_a)
		}
		if tex_b.id != 0 {
			gfx.destroy_image(tex_b)
		}
		if depth.id != 0 {
			gfx.destroy_image(depth)
		}
		window.filter_state.tex_width = 0
		window.filter_state.tex_height = 0
		return false
	}

	mut att_colors_a := [4]gfx.AttachmentDesc{}
	att_colors_a[0] = gfx.AttachmentDesc{
		image: tex_a
	}
	att_a := gfx.make_attachments(gfx.AttachmentsDesc{
		colors:        att_colors_a
		depth_stencil: gfx.AttachmentDesc{
			image: depth
		}
		label:         c'filter_att_a'
	})

	mut att_colors_b := [4]gfx.AttachmentDesc{}
	att_colors_b[0] = gfx.AttachmentDesc{
		image: tex_b
	}
	att_b := gfx.make_attachments(gfx.AttachmentsDesc{
		colors:        att_colors_b
		depth_stencil: gfx.AttachmentDesc{
			image: depth
		}
		label:         c'filter_att_b'
	})
	if att_a.id == 0 || att_b.id == 0 {
		if att_a.id != 0 {
			gfx.destroy_attachments(att_a)
		}
		if att_b.id != 0 {
			gfx.destroy_attachments(att_b)
		}
		gfx.destroy_image(tex_a)
		gfx.destroy_image(tex_b)
		gfx.destroy_image(depth)
		window.filter_state.tex_width = 0
		window.filter_state.tex_height = 0
		return false
	}

	window.filter_state.tex_a = tex_a
	window.filter_state.tex_b = tex_b
	window.filter_state.depth = depth
	window.filter_state.att_a = att_a
	window.filter_state.att_b = att_b

	window.filter_state.tex_width = w
	window.filter_state.tex_height = h
	return true
}

// draw_filter_quad draws a textured quad with UVs from 0..1.
fn draw_filter_quad(r &render.Context, x f32, y f32, w f32, h f32) {
	r.begin_quads()

	r.t2f(0.0, 0.0)
	r.v3f(x, y, 0.0)

	r.t2f(1.0, 0.0)
	r.v3f(x + w, y, 0.0)

	r.t2f(1.0, 1.0)
	r.v3f(x + w, y + h, 0.0)

	r.t2f(0.0, 1.0)
	r.v3f(x, y + h, 0.0)

	r.end()
}

fn init_image_clip_pipeline(mut window Window) bool {
	if window.pip.image_clip.id != 0 {
		return true
	}
	if window.pip.image_clip_init_failed {
		return false
	}
	window.pip.image_clip = make_gui_builtin_render_pipeline(window.ui.r, c'image_clip_pip',
		gfx.make_shader(voidptr(C.gui_image_clip_shader_desc(gfx.query_backend()))))
	if window.pip.image_clip.id == 0 {
		window.pip.image_clip_init_failed = true
		return false
	}
	window.pip.image_clip_init_failed = false
	window.pip.image_clip_fallback_warned = false
	return true
}

@[inline]
fn warn_image_clip_fallback_once(mut window Window) {
	if window.pip.image_clip_fallback_warned {
		return
	}
	window.pip.image_clip_fallback_warned = true
	log.warn('image_clip pipeline unavailable; fallback to unclipped')
}

@[inline]
fn rounded_image_scaled_params(x f32, y f32, w f32, h f32, radius f32, scale f32) (f32, f32, f32, f32, f32) {
	x0 := x * scale
	y0 := y * scale
	w0 := w * scale
	h0 := h * scale
	mut r := radius * scale
	if math.is_nan(r) || math.is_inf(r, 0) {
		r = 0
	}
	min_dim := if w0 < h0 { w0 } else { h0 }
	if r > min_dim / 2.0 {
		r = min_dim / 2.0
	}
	if r < 0 {
		r = 0
	}
	return x0, y0, w0, h0, r
}

// draw_image_rounded draws a textured quad with SDF rounded-rect
// alpha masking. Uses draw_quad (UVs -1..1) with the image_clip
// pipeline; the fragment shader remaps to 0..1 for texture
// sampling.
fn draw_image_rounded(x f32, y f32, w f32, h f32, radius f32, img &gg.Image, mut window Window) {
	if w <= 0 || h <= 0 {
		return
	}

	if !init_image_clip_pipeline(mut window) {
		warn_image_clip_fallback_once(mut window)
		window.ui.draw_image(x, y, w, h, img)
		return
	}

	x0, y0, w0, h0, r := rounded_image_scaled_params(x, y, w, h, radius, window.ui.scale)
	z := pack_shader_params(r, 0)

	window.ui.r.load_pipeline(window.pip.image_clip)
	window.ui.r.enable_texture()
	window.ui.r.texture(img.simg, img.ssmp)
	window.ui.r.c4b(255, 255, 255, 255)
	draw_quad(window.ui.r, x0, y0, w0, h0, z)

	window.ui.r.disable_texture()
	window.ui.r.load_default_pipeline()
}

fn draw_quad(r &render.Context, x f32, y f32, w f32, h f32, z f32) {
	r.begin_quads()

	// Why UVs from -1.0 to 1.0?
	// Standard textures use 0.0 to 1.0. However, for procedural shapes based on math (SDFs),
	// it is much easier to work with a coordinate system where (0,0) is the center of the shape.
	// Mapping the quad corners to (-1,-1)...(1,1) allows the interpolation in the fragment shader
	// to provide a centered coordinate system automatically.

	// Top Left
	r.t2f(-1.0, -1.0)
	r.v3f(x, y, z)

	// Top Right
	r.t2f(1.0, -1.0)
	r.v3f(x + w, y, z)

	// Bottom Right
	r.t2f(1.0, 1.0)
	r.v3f(x + w, y + h, z)

	// Bottom Left
	r.t2f(-1.0, 1.0)
	r.v3f(x, y + h, z)

	r.end()
}
