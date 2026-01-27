module gui

// The `shaders.v` module provides high-performance rendering primitives for

// rounded rectangles, using signed distance field (SDF) shaders via sokol.sgl.
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
import sokol.sgl
import sokol.gfx
import math

const packing_stride = 1000.0

// pack_shader_params packs radius and thickness into a single f32 for the shader.
// The value is stored in the z-coordinate of the vertex position.
//
// Why pack parameters?
// The Z-coordinate of the position vector is used to transport per-instance data (radius, thickness)
// to the shader without requiring additional vertex attributes or breaking the batch
// by updating uniforms. This allows drawing many rounded rects with different properties
// in a single draw call.
//
// Packing Strategy:
// radius: Stored in the thousands place (e.g., 5.0 -> 5000.0).
// thickness: Stored in the units place (e.g., 2.0 -> 2.0).
// Result: 5002.0.
// Limit: Thickness must be less than 1000.0 pixels.
@[inline]
fn pack_shader_params(radius f32, thickness f32) f32 {
	return thickness + (f32(math.floor(radius)) * f32(packing_stride))
}

fn init_rounded_rect_pipeline(mut window Window) {
	if window.rounded_rect_pip_init {
		return
	}
	// Why a custom pipeline?
	// A specific shader program (Vertex & Fragment) is required to implement the SDF logic.
	// Standard immediate-mode rendering (sgl) generally uses a generic shader for coloured triangles.
	// This pipeline configures the GPU to interpret vertex data specifically for SDF rendering
	// and executes the corresponding fragment shader.

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
	// These map the vertex attribute buffers to the specific inputs defined in the shader code.
	mut shader_attrs := [16]gfx.ShaderAttrDesc{}
	// Map vertex buffer 'position' to shader input 'position' (semantic POSITION, index 0)
	shader_attrs[0] = gfx.ShaderAttrDesc{
		name:      c'position'
		sem_name:  c'POSITION'
		sem_index: 0
	}
	// Map vertex buffer 'texcoord0' to shader input 'texcoord0' (semantic TEXCOORD, index 0)
	shader_attrs[1] = gfx.ShaderAttrDesc{
		name:      c'texcoord0'
		sem_name:  c'TEXCOORD'
		sem_index: 0
	}
	// Map vertex buffer 'color0' to shader input 'color0' (semantic COLOR, index 0)
	shader_attrs[2] = gfx.ShaderAttrDesc{
		name:      c'color0'
		sem_name:  c'COLOR'
		sem_index: 0
	}

	// Uniform Definitions
	// Define the layout of uniform blocks (constant data) passed to the shader.
	mut ub_uniforms := [16]gfx.ShaderUniformDesc{}
	// mvp: Model-View-Projection matrix (4x4 float matrix).
	// usage: Transforms vertices from model space to clip space.
	ub_uniforms[0] = gfx.ShaderUniformDesc{
		name:        c'mvp'
		@type:       .mat4
		array_count: 1
	}
	// tm: Texture Matrix or auxiliary matrix.
	// usage: In this pipeline, it is reserved for compatibility or future texture transforms.
	ub_uniforms[1] = gfx.ShaderUniformDesc{
		name:        c'tm'
		@type:       .mat4
		array_count: 1
	}

	// Uniform Block
	// Groups uniforms into a single bindable block.
	mut ub := [4]gfx.ShaderUniformBlockDesc{}
	ub[0] = gfx.ShaderUniformBlockDesc{
		size:     128 // Size: 64 bytes (mvp) + 64 bytes (tm) = 128 bytes.
		uniforms: ub_uniforms
	}

	// Color Targets & Blending
	// Configures how the pixel shader output is written to the framebuffer.
	mut colors := [4]gfx.ColorTargetState{}
	colors[0] = gfx.ColorTargetState{
		blend:      gfx.BlendState{
			enabled: true
			// Src Alpha: Use the fragment's calculated alpha (from SDF).
			src_factor_rgb: .src_alpha
			// One Minus Src Alpha: Standard alpha blending (background * (1-alpha)).
			dst_factor_rgb:   .one_minus_src_alpha
			src_factor_alpha: .one
			dst_factor_alpha: .one_minus_src_alpha
		}
		write_mask: .rgba // Enable writing to Red, Green, Blue, and Alpha channels.
	}

	// Texture Images
	// Defines expected texture inputs. sgl generic pipelines expect a texture.
	mut shader_images := [12]gfx.ShaderImageDesc{}
	shader_images[0] = gfx.ShaderImageDesc{
		used:        true
		image_type:  ._2d
		sample_type: .float
	}

	// Texture Samplers
	// Defines how textures are sampled (filtering, wrapping).
	mut shader_samplers := [8]gfx.ShaderSamplerDesc{}
	shader_samplers[0] = gfx.ShaderSamplerDesc{
		used:         true
		sampler_type: .filtering // Linear filtering.
	}

	// Image-Sampler Pairs
	// Maps images to samplers for the shader.
	mut shader_image_sampler_pairs := [12]gfx.ShaderImageSamplerPairDesc{}
	shader_image_sampler_pairs[0] = gfx.ShaderImageSamplerPairDesc{
		used:         true
		image_slot:   0
		sampler_slot: 0
		glsl_name:    c'tex' // Name of the sampler2D in GLSL code.
	}

	// Shader Description
	// Compiles the shader stages (Vertex & Fragment) into a shader program (backend specific).
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

	// Pipeline Description
	// Final assembly of the render pipeline state object (PSO).
	// Combines shader, layout, and render state into an immutable object.
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
	// Attribute 0: Position (x, y, z)
	// - x, y: Screen coordinates of the vertex.
	// - z: Packed parameters (radius, blur/thickness). See pack_shader_params().
	// Format .float3 means 3 x 32-bit floats.
	attrs[0] = gfx.VertexAttrDesc{
		format:       .float3
		offset:       0
		buffer_index: 0
	}
	// Attribute 1: Texture Coordinates (u, v)
	// - u, v: Normalized coordinates (-1.0 to 1.0) used for SDF calculation.
	// Format .float2 means 2 x 32-bit floats.
	attrs[1] = gfx.VertexAttrDesc{
		format:       .float2
		offset:       12
		buffer_index: 0
	}
	// Attribute 2: Color (r, g, b, a)
	// - Standard RGBA color for the vertex.
	// Format .ubyte4n means 4 unsigned bytes, normalized to 0.0-1.0 range.
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
	// Shadow Mapping:
	// Matches vertex attributes to the shadow shader inputs.
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

	// Uniform Definitions (Shadow)
	// Same layout as standard pipeline: MVP + Texture Matrix.
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

	// Uniform Block (Shadow)
	mut ub := [4]gfx.ShaderUniformBlockDesc{}
	ub[0] = gfx.ShaderUniformBlockDesc{
		size:     128
		uniforms: ub_uniforms
	}

	// Color Targets (Shadow)
	// Same blending as rounded rect: Src Alpha / One Minus Src Alpha.
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
	// Texture Images (Shadow)
	// Even though our shadow is procedural, sgl requires a texture slot definition.
	mut shader_images := [12]gfx.ShaderImageDesc{}
	shader_images[0] = gfx.ShaderImageDesc{
		used:        true
		image_type:  ._2d
		sample_type: .float
	}
	// Texture Samplers (Shadow)
	mut shader_samplers := [8]gfx.ShaderSamplerDesc{}
	shader_samplers[0] = gfx.ShaderSamplerDesc{
		used:         true
		sampler_type: .filtering
	}
	// Image-Sampler Pairs (Shadow)
	mut shader_image_sampler_pairs := [12]gfx.ShaderImageSamplerPairDesc{}
	shader_image_sampler_pairs[0] = gfx.ShaderImageSamplerPairDesc{
		used:         true
		image_slot:   0
		sampler_slot: 0
		glsl_name:    c'tex'
	}

	// Shader Description (Shadow)
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

	// Pipeline Description (Shadow)
	// Assembles the shadow rendering pipeline.
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

// init_blur_pipeline initializes the pipeline for a standalone Gaussian blur effect.
// It shares the same vertex attributes as the shadow pipeline but uses a specific
// fragment shader intended for blurring content without the complexities of the drop-shadow offset logic.
fn init_blur_pipeline(mut window Window) {
	if window.blur_pip_init {
		return
	}

	mut attrs := [16]gfx.VertexAttrDesc{}
	// Attribute 0: Position & Packed Params
	// The Z component carries the blur radius and corner radius data to the shader.
	attrs[0] = gfx.VertexAttrDesc{
		format:       .float3
		offset:       0
		buffer_index: 0
	}
	// Attribute 1: Texture Coordinates
	// Used to compute the distance from the center of the shape (SDF).
	attrs[1] = gfx.VertexAttrDesc{
		format:       .float2
		offset:       12
		buffer_index: 0
	}
	// Attribute 2: Vertex Color
	// Base color of the shape, multiplied by the calculated alpha from the SDF.
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
	// Blur Mapping:
	// Identical mapping for the blur shader.
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

	// Uniform Definitions (Blur)
	// Same layout as standard pipeline: MVP + Texture Matrix.
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

	// Uniform Block (Blur)
	mut ub := [4]gfx.ShaderUniformBlockDesc{}
	ub[0] = gfx.ShaderUniformBlockDesc{
		size:     128
		uniforms: ub_uniforms
	}

	// Color Targets (Blur)
	// Same blending as rounded rect: Src Alpha / One Minus Src Alpha.
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

	// Texture Images (Blur)
	mut shader_images := [12]gfx.ShaderImageDesc{}
	shader_images[0] = gfx.ShaderImageDesc{
		used:        true
		image_type:  ._2d
		sample_type: .float
	}
	// Texture Samplers (Blur)
	mut shader_samplers := [8]gfx.ShaderSamplerDesc{}
	shader_samplers[0] = gfx.ShaderSamplerDesc{
		used:         true
		sampler_type: .filtering // Linear filtering.
	}
	// Image-Sampler Pairs (Blur)
	mut shader_image_sampler_pairs := [12]gfx.ShaderImageSamplerPairDesc{}
	shader_image_sampler_pairs[0] = gfx.ShaderImageSamplerPairDesc{
		used:         true
		image_slot:   0
		sampler_slot: 0
		glsl_name:    c'tex'
	}

	// Shader Description (Blur)
	mut shader_desc := gfx.ShaderDesc{
		attrs: shader_attrs
	}

	$if macos {
		shader_desc.vs = gfx.ShaderStageDesc{
			// Reusing shadow vertex shader as it has params/offset
			source:         vs_shadow_metal.str
			entry:          c'vs_main'
			uniform_blocks: ub
		}
		shader_desc.fs = gfx.ShaderStageDesc{
			source:              fs_blur_metal.str
			entry:               c'fs_main'
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
			source:              fs_blur_glsl.str
			images:              shader_images
			samplers:            shader_samplers
			image_sampler_pairs: shader_image_sampler_pairs
		}
	}

	// Pipeline Description (Blur)
	// Assembles the blur rendering pipeline.
	desc := gfx.PipelineDesc{
		label:  c'blur_pip'
		colors: colors
		layout: gfx.VertexLayoutState{
			attrs:   attrs
			buffers: buffers
		}
		shader: gfx.make_shader(&shader_desc)
	}

	window.blur_pip = sgl.make_pipeline(&desc)
	window.blur_pip_init = true
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
	// Translate by the NEGATIVE offset because the "clip box" needs to be shifted
	// relative to the shadow.
	// The shadow is drawn at (x,y) which INCLUDES the offset.
	// The casting box is at (x - offset_x, y - offset_y).
	// So the coordinate system must be shifted so that (0,0) aligns correctly.
	// sgl doesn't have a generic "set uniform" for custom uniforms easily accessible here without breaking abstraction.
	// The Translation part of the matrix is used to pass this data.

	sgl.translate(ox, oy, 0.0)

	sgl.load_pipeline(window.shadow_pip)
	sgl.c4b(c.r, c.g, c.b, c.a)

	// Pack radius and blur. Blur is stored in fractional part or just use packing logic.
	// pack_shader_params: return thickness + (radius * 1000)
	// Here blur corresponds to thickness in the packing: blur + (radius * 1000)
	z_val := pack_shader_params(r, b)

	draw_quad(sx, sy, sw, sh, z_val)
	sgl.load_default_pipeline()

	sgl.pop_matrix()
	sgl.matrix_mode_modelview()
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

	init_rounded_rect_pipeline(mut window)

	sgl.load_pipeline(window.rounded_rect_pip)
	sgl.c4b(c.r, c.g, c.b, c.a)

	z_val := pack_shader_params(r, 0)

	draw_quad(sx, sy, sw, sh, z_val)
	sgl.load_default_pipeline()
}

// draw_rounded_rect_empty draws a broaded (stroked) rounded rectangle.
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

	init_rounded_rect_pipeline(mut window)

	sgl.load_pipeline(window.rounded_rect_pip)
	sgl.c4b(c.r, c.g, c.b, c.a)

	// Pack parameters: r + thickness * 10000
	z_val := pack_shader_params(r, thickness * scale)

	draw_quad(sx, sy, sw, sh, z_val)
	sgl.load_default_pipeline()
}

fn draw_quad(x f32, y f32, w f32, h f32, z f32) {
	sgl.begin_quads()

	// Why UVs from -1.0 to 1.0?
	// Standard textures use 0.0 to 1.0. However, for procedural shapes based on math (SDFs),
	// it is much easier to work with a coordinate system where (0,0) is the center of the shape.
	// Mapping the quad corners to (-1,-1)...(1,1) allows the interpolation in the fragment shader
	// to provide a centered coordinate system automatically.

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
