module gui

// The `shaders.v` module provides high-performance rendering primitives for

// rounded rectangles, using signed distance field (SDF) shaders via sokol.sgl.
// This replaces the previous discrete triangle implementation.
import gg
import sokol.sgl
import sokol.gfx
import math

const packing_stride = 1000.0

// pack_shader_params packs radius and thickness into a single f32 for the shader.
// The value is stored in the z-coordinate of the vertex position.
// radius: the corner radius in pixels.
// thickness: the border thickness in pixels (0 for filled).
@[inline]
fn pack_shader_params(radius f32, thickness f32) f32 {
	return thickness + (f32(math.floor(radius)) * f32(packing_stride))
}

fn init_rounded_rect_pipeline(mut window Window) {
	if window.rounded_rect_pip_init {
		return
	}

	// Vertex layout
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

	// Shader attributes
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
		size:     128 // sgl uses 128 bytes (mvp + tm)
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
		shader_desc.vs = gfx.ShaderStageDesc{
			source:         vs_metal.str // Use .str for &char
			entry:          c'vs_main'
			uniform_blocks: ub
		}
		shader_desc.fs = gfx.ShaderStageDesc{
			source:              fs_metal.str
			entry:               c'fs_main'
			images:              shader_images
			samplers:            shader_samplers
			image_sampler_pairs: shader_image_sampler_pairs
		}
	} $else {
		shader_desc.vs = gfx.ShaderStageDesc{
			source:         vs_glsl.str
			uniform_blocks: ub
		}
		shader_desc.fs = gfx.ShaderStageDesc{
			source:              fs_glsl.str
			images:              shader_images
			samplers:            shader_samplers
			image_sampler_pairs: shader_image_sampler_pairs
		}
	}

	desc := gfx.PipelineDesc{
		label:  c'rounded_rect_pip'
		colors: colors
		layout: gfx.VertexLayoutState{
			attrs:   attrs
			buffers: buffers
		}
		shader: gfx.make_shader(&shader_desc)
	}

	window.rounded_rect_pip = sgl.make_pipeline(&desc)
	window.rounded_rect_pip_init = true
}

// Metal Shader Source (MSL) for Shadows

// init_shadow_pipeline initializes the sgl pipeline specifically for rendering drop shadows.
// It uses a custom shader (vs_shadow/fs_shadow) that implements a Gaussian-like blur approximation
// using Signed Distance Fields (SDF).
fn init_shadow_pipeline(mut window Window) {
	if window.shadow_pip_init {
		return
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

	// Images/Samplers setup (standard sgl requirement)
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
		shader_desc.vs = gfx.ShaderStageDesc{
			source:         vs_shadow_metal.str
			entry:          c'vs_main'
			uniform_blocks: ub
		}
		shader_desc.fs = gfx.ShaderStageDesc{
			source: fs_shadow_metal.str
			entry:  c'fs_main'

			images:              shader_images
			samplers:            shader_samplers
			image_sampler_pairs: shader_image_sampler_pairs
		}
	} $else {
		shader_desc.vs = gfx.ShaderStageDesc{
			source:         vs_shadow_glsl.str
			uniform_blocks: ub
		}
		shader_desc.fs = gfx.ShaderStageDesc{
			source:              fs_shadow_glsl.str
			images:              shader_images
			samplers:            shader_samplers
			image_sampler_pairs: shader_image_sampler_pairs
		}
	}

	desc := gfx.PipelineDesc{
		label:  c'shadow_pip'
		colors: colors
		layout: gfx.VertexLayoutState{
			attrs:   attrs
			buffers: buffers
		}
		shader: gfx.make_shader(&shader_desc)
	}

	window.shadow_pip = sgl.make_pipeline(&desc)
	window.shadow_pip_init = true
}

// draw_shadow_rect draws a rounded rectangle drop shadow.
// x, y, w, h specifies the bounding box of the *casting element* (not the shadow itself).
// The shadow geometry is automatically expanded based on the blur radius.
// The shadow is rendered as a "hollow" rim shadow (fading out from the edge in both directions),
// ensuring correct appearance for both filled and transparent containers.
// radius: The corner radius of the casting element.
// blur: The blur radius (standard deviation approximation).
pub fn draw_shadow_rect(x f32, y f32, w f32, h f32, radius f32, blur f32, c gg.Color, offset_x f32, offset_y f32, mut window Window) {
	if c.a == 0 {
		return
	}

	scale := window.ui.scale
	// We draw a larger quad to accommodate the blur
	// Padding = blur radius * 1.5 to be safe
	padding := blur * 1.5

	sx := (x - padding) * scale
	sy := (y - padding) * scale
	sw := (w + padding * 2) * scale
	sh := (h + padding * 2) * scale

	r := radius * scale
	b := blur * scale

	ox := offset_x * scale
	oy := offset_y * scale

	init_shadow_pipeline(mut window)

	// Pass offset via Texture Matrix
	sgl.matrix_mode_texture()
	sgl.push_matrix()
	sgl.load_identity()
	// We translate by the NEGATIVE offset because we want to shift the "clip box"
	// relative to the shadow.
	// The shadow is drawn at (x,y) which INCLUDES the offset.
	// The casting box is at (x - offset_x, y - offset_y).
	// So we want to shift the coordinate system so that (0,0) aligns with... wait.
	// We simply want to pass the offset to the shader.
	// sgl doesn't have a generic "set uniform" for custom uniforms easily accessible here without breaking abstraction?
	// sgl uses the texture matrix for its own purposes? No, usually not.
	// We can use the Translation part of the matrix.

	sgl.translate(ox, oy, 0.0)

	sgl.load_pipeline(window.shadow_pip)
	sgl.c4b(c.r, c.g, c.b, c.a)

	// Pack radius and blur. Blur is stored in fractional part or just use packing logic.
	// pack_shader_params: return thickness + (radius * 1000)
	// Here we can pack: blur + (radius * 1000)
	z_val := pack_shader_params(r, b)

	draw_quad(sx, sy, sw, sh, z_val)
	sgl.load_default_pipeline()

	sgl.pop_matrix()
	sgl.matrix_mode_modelview()
}

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

	init_rounded_rect_pipeline(mut window)

	sgl.load_pipeline(window.rounded_rect_pip)
	sgl.c4b(c.r, c.g, c.b, c.a)

	z_val := pack_shader_params(r, 0)

	draw_quad(sx, sy, sw, sh, z_val)
	sgl.load_default_pipeline()
}

pub fn draw_rounded_rect_empty(x f32, y f32, w f32, h f32, radius f32, c gg.Color, mut window Window) {
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

	init_rounded_rect_pipeline(mut window)

	sgl.load_pipeline(window.rounded_rect_pip)
	sgl.c4b(c.r, c.g, c.b, c.a)

	// Pack parameters: r + thickness * 10000
	z_val := pack_shader_params(r, 1.5 * scale)

	draw_quad(sx, sy, sw, sh, z_val)
	sgl.load_default_pipeline()
}

fn draw_quad(x f32, y f32, w f32, h f32, z f32) {
	sgl.begin_quads()

	// UV -1.0 to 1.0 range for SDF. Attributes (t2f) must be set before v3f.

	// Top Left
	sgl.t2f(-1.0, -1.0)
	sgl.v3f(x, y, z)

	// Top Right
	sgl.t2f(1.0, -1.0)
	sgl.v3f(x + w, y, z)

	// Bottom Right
	sgl.t2f(1.0, 1.0)
	sgl.v3f(x + w, y + h, z)

	// Bottom Left
	sgl.t2f(-1.0, 1.0)
	sgl.v3f(x, y + h, z)

	sgl.end()
}
