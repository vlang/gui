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
import log
import sokol.sapp
import sokol.sgl
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
	blur_h_pip       gfx.Pipeline // raw gfx: horizontal blur
	blur_v_pip       gfx.Pipeline // raw gfx: vertical blur
	content_pip      gfx.Pipeline // raw gfx: colored triangles
	texture_quad_pip sgl.Pipeline // SGL: composite to swapchain
	quad_vbuf        gfx.Buffer   // static unit quad (blur passes)
	content_vbuf     gfx.Buffer   // dynamic buffer for SVG content
	content_vbuf_sz  int          // current content buffer capacity
	scratch_vertices []FilterVertex
	initialized      bool
}

// Pipelines holds lazily-initialized GPU rendering pipelines.
// Each pipeline is considered initialized when its `.id != 0`.
struct Pipelines {
mut:
	rounded_rect               sgl.Pipeline
	shadow                     sgl.Pipeline
	blur                       sgl.Pipeline
	gradient                   sgl.Pipeline
	image_clip                 sgl.Pipeline
	image_clip_init_failed     bool
	image_clip_fallback_warned bool
	stencil_write              sgl.Pipeline
	stencil_test               sgl.Pipeline
	stencil_clear              sgl.Pipeline
	custom                     map[u64]sgl.Pipeline
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

fn init_rounded_rect_pipeline(mut window Window) bool {
	if window.pip.rounded_rect.id != 0 {
		return true
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

	window.pip.rounded_rect = sgl.make_pipeline(&desc)
	return window.pip.rounded_rect.id != 0
}

// Metal Shader Source (MSL) for Shadows

// init_shadow_pipeline initializes the sgl pipeline specifically for rendering drop shadows.
// It uses a custom shader (vs_shadow/fs_shadow) that implements a Gaussian-like blur approximation
// using Signed Distance Fields (SDF).
fn init_shadow_pipeline(mut window Window) {
	if window.pip.shadow.id != 0 {
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

	window.pip.shadow = sgl.make_pipeline(&desc)
}

// init_blur_pipeline initializes the pipeline for a standalone Gaussian blur effect.
// It shares the same vertex attributes as the shadow pipeline but uses a specific
// fragment shader intended for blurring content without the complexities of the drop-shadow offset logic.
fn init_blur_pipeline(mut window Window) {
	if window.pip.blur.id != 0 {
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

	window.pip.blur = sgl.make_pipeline(&desc)
}

// init_gradient_pipeline initializes the pipeline for multi-stop gradient rendering.
// It uses custom shaders (vs_gradient/fs_gradient) that implement CSS-style gradients
// with 3 color stops packed into the tm uniform matrix.
fn init_gradient_pipeline(mut window Window) {
	if window.pip.gradient.id != 0 {
		return
	}

	mut attrs := [16]gfx.VertexAttrDesc{}
	// Attribute 0: Position (x, y, z)
	attrs[0] = gfx.VertexAttrDesc{
		format:       .float3
		offset:       0
		buffer_index: 0
	}
	// Attribute 1: Texture Coordinates (u, v)
	attrs[1] = gfx.VertexAttrDesc{
		format:       .float2
		offset:       12
		buffer_index: 0
	}
	// Attribute 2: Color (r, g, b, a)
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

	// Uniform Definitions (Gradient)
	// tm matrix carries gradient stop data: tm[0..2] as vec4(r,g,b,pos)
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

	// Uniform Block (Gradient)
	mut ub := [4]gfx.ShaderUniformBlockDesc{}
	ub[0] = gfx.ShaderUniformBlockDesc{
		size:     128
		uniforms: ub_uniforms
	}

	// Color Targets (Gradient)
	// Alpha blending for gradient transparency
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

	// Texture Images (Gradient)
	mut shader_images := [12]gfx.ShaderImageDesc{}
	shader_images[0] = gfx.ShaderImageDesc{
		used:        true
		image_type:  ._2d
		sample_type: .float
	}
	// Texture Samplers (Gradient)
	mut shader_samplers := [8]gfx.ShaderSamplerDesc{}
	shader_samplers[0] = gfx.ShaderSamplerDesc{
		used:         true
		sampler_type: .filtering
	}
	// Image-Sampler Pairs (Gradient)
	mut shader_image_sampler_pairs := [12]gfx.ShaderImageSamplerPairDesc{}
	shader_image_sampler_pairs[0] = gfx.ShaderImageSamplerPairDesc{
		used:         true
		image_slot:   0
		sampler_slot: 0
		glsl_name:    c'tex'
	}

	// Shader Description (Gradient)
	mut shader_desc := gfx.ShaderDesc{
		attrs: shader_attrs
	}

	$if macos {
		shader_desc.vs = gfx.ShaderStageDesc{
			source:         vs_gradient_metal.str
			entry:          c'vs_main'
			uniform_blocks: ub
		}
		shader_desc.fs = gfx.ShaderStageDesc{
			source:              fs_gradient_metal.str
			entry:               c'fs_main'
			images:              shader_images
			samplers:            shader_samplers
			image_sampler_pairs: shader_image_sampler_pairs
		}
	} $else {
		shader_desc.vs = gfx.ShaderStageDesc{
			source:         vs_gradient_glsl.str
			uniform_blocks: ub
		}
		shader_desc.fs = gfx.ShaderStageDesc{
			source:              fs_gradient_glsl.str
			images:              shader_images
			samplers:            shader_samplers
			image_sampler_pairs: shader_image_sampler_pairs
		}
	}

	// Pipeline Description (Gradient)
	desc := gfx.PipelineDesc{
		label:  c'gradient_pip'
		colors: colors
		layout: gfx.VertexLayoutState{
			attrs:   attrs
			buffers: buffers
		}
		shader: gfx.make_shader(&shader_desc)
	}

	window.pip.gradient = sgl.make_pipeline(&desc)
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

	sgl.load_pipeline(window.pip.shadow)
	sgl.c4b(c.r, c.g, c.b, c.a)

	// Pack radius and blur using the fixed-point packer.
	z_val := pack_shader_params(r, b)

	draw_quad(sx, sy, sw, sh, z_val)
	sgl.load_default_pipeline()
	sgl.c4b(255, 255, 255, 255) // Reset color state

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

	if !init_rounded_rect_pipeline(mut window) {
		return
	}

	sgl.load_pipeline(window.pip.rounded_rect)
	sgl.c4b(c.r, c.g, c.b, c.a)

	z_val := pack_shader_params(r, 0)

	draw_quad(sx, sy, sw, sh, z_val)
	sgl.load_default_pipeline()
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

	sgl.load_pipeline(window.pip.rounded_rect)
	sgl.c4b(c.r, c.g, c.b, c.a)

	// Pack radius and stroke thickness.
	z_val := pack_shader_params(r, thickness * scale)

	draw_quad(sx, sy, sw, sh, z_val)
	sgl.load_default_pipeline()
}

// init_stencil_pipelines creates two sgl pipelines for clipPath
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
		window.pip.stencil_write = sgl.make_pipeline(&desc_w)
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
		window.pip.stencil_test = sgl.make_pipeline(&desc_t)
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
		window.pip.stencil_clear = sgl.make_pipeline(&desc_c)
	}
}

// init_custom_pipeline creates and caches a pipeline for a custom
// fragment shader. Pipelines are keyed by source hash so identical
// shader bodies share a single compiled pipeline.
fn init_custom_pipeline(shader &Shader, mut window Window) sgl.Pipeline {
	key := shader_hash(shader)
	if pip := window.pip.custom[key] {
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

	pip := sgl.make_pipeline(&desc)
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

	// Load user params into tm matrix
	sgl.matrix_mode_texture()
	sgl.push_matrix()

	mut tm_data := [16]f32{}
	max_params := if shader.params.len > 16 { 16 } else { shader.params.len }
	for i in 0 .. max_params {
		tm_data[i] = shader.params[i]
	}
	sgl.load_matrix(tm_data[0..])

	sgl.load_pipeline(pip)
	sgl.c4b(c.r, c.g, c.b, c.a)

	z_val := pack_shader_params(r, 0)
	draw_quad(sx, sy, sw, sh, z_val)

	sgl.load_default_pipeline()
	sgl.c4b(255, 255, 255, 255)
	sgl.pop_matrix()
	sgl.matrix_mode_modelview()
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
// rendering (blur passes). Uses images/samplers for texture sampling.
fn make_filter_gfx_pipeline(vs_src string, fs_src string, vs_entry &u8, fs_entry &u8, glsl_sampler_name &u8) gfx.Pipeline {
	mut attrs := [16]gfx.VertexAttrDesc{}
	attrs[0] = gfx.VertexAttrDesc{
		format: .float3
		offset: 0
	}
	attrs[1] = gfx.VertexAttrDesc{
		format: .float2
		offset: 12
	}
	attrs[2] = gfx.VertexAttrDesc{
		format: .ubyte4n
		offset: 20
	}
	mut buffers := [8]gfx.VertexBufferLayoutState{}
	buffers[0] = gfx.VertexBufferLayoutState{
		stride: 24
	}
	layout := gfx.VertexLayoutState{
		attrs:   attrs
		buffers: buffers
	}

	mut shader_attrs := [16]gfx.ShaderAttrDesc{}
	shader_attrs[0] = gfx.ShaderAttrDesc{
		name:     c'position'
		sem_name: c'POSITION'
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
	unsafe {
		shader_image_sampler_pairs[0] = gfx.ShaderImageSamplerPairDesc{
			used:         true
			image_slot:   0
			sampler_slot: 0
			glsl_name:    glsl_sampler_name
		}
	}
	mut shader_desc := gfx.ShaderDesc{
		attrs: shader_attrs
	}
	$if macos {
		unsafe {
			shader_desc.vs = gfx.ShaderStageDesc{
				source:         vs_src.str
				entry:          vs_entry
				uniform_blocks: ub
			}
			shader_desc.fs = gfx.ShaderStageDesc{
				source:              fs_src.str
				entry:               fs_entry
				images:              shader_images
				samplers:            shader_samplers
				image_sampler_pairs: shader_image_sampler_pairs
			}
		}
	} $else {
		shader_desc.vs = gfx.ShaderStageDesc{
			source:         vs_src.str
			uniform_blocks: ub
		}
		shader_desc.fs = gfx.ShaderStageDesc{
			source:              fs_src.str
			images:              shader_images
			samplers:            shader_samplers
			image_sampler_pairs: shader_image_sampler_pairs
		}
	}

	return gfx.make_pipeline(&gfx.PipelineDesc{
		label:  c'filter_gfx_pip'
		layout: layout
		colors: colors
		shader: gfx.make_shader(&shader_desc)
	})
}

// make_content_gfx_pipeline creates a raw gfx.Pipeline for rendering
// colored triangles to offscreen texture (no texture sampling).
fn make_content_gfx_pipeline(vs_src string, fs_src string, vs_entry &u8, fs_entry &u8) gfx.Pipeline {
	mut attrs := [16]gfx.VertexAttrDesc{}
	attrs[0] = gfx.VertexAttrDesc{
		format: .float3
		offset: 0
	}
	attrs[1] = gfx.VertexAttrDesc{
		format: .float2
		offset: 12
	}
	attrs[2] = gfx.VertexAttrDesc{
		format: .ubyte4n
		offset: 20
	}
	mut buffers := [8]gfx.VertexBufferLayoutState{}
	buffers[0] = gfx.VertexBufferLayoutState{
		stride: 24
	}
	layout := gfx.VertexLayoutState{
		attrs:   attrs
		buffers: buffers
	}

	mut shader_attrs := [16]gfx.ShaderAttrDesc{}
	shader_attrs[0] = gfx.ShaderAttrDesc{
		name:     c'position'
		sem_name: c'POSITION'
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

	mut shader_desc := gfx.ShaderDesc{
		attrs: shader_attrs
	}
	$if macos {
		unsafe {
			shader_desc.vs = gfx.ShaderStageDesc{
				source:         vs_src.str
				entry:          vs_entry
				uniform_blocks: ub
			}
			shader_desc.fs = gfx.ShaderStageDesc{
				source: fs_src.str
				entry:  fs_entry
			}
		}
	} $else {
		shader_desc.vs = gfx.ShaderStageDesc{
			source:         vs_src.str
			uniform_blocks: ub
		}
		shader_desc.fs = gfx.ShaderStageDesc{
			source: fs_src.str
		}
	}

	return gfx.make_pipeline(&gfx.PipelineDesc{
		label:  c'content_gfx_pip'
		layout: layout
		colors: colors
		shader: gfx.make_shader(&shader_desc)
	})
}

// make_filter_sgl_pipeline creates an SGL pipeline for compositing
// the blurred result onto the swapchain.
fn make_filter_sgl_pipeline(ctx sgl.Context, vs_src string, fs_src string, vs_entry &u8, fs_entry &u8, glsl_sampler_name &u8) sgl.Pipeline {
	mut attrs := [16]gfx.VertexAttrDesc{}
	attrs[0] = gfx.VertexAttrDesc{
		format: .float3
		offset: 0
	}
	attrs[1] = gfx.VertexAttrDesc{
		format: .float2
		offset: 12
	}
	attrs[2] = gfx.VertexAttrDesc{
		format: .ubyte4n
		offset: 20
	}
	mut buffers := [8]gfx.VertexBufferLayoutState{}
	buffers[0] = gfx.VertexBufferLayoutState{
		stride: 24
	}
	layout := gfx.VertexLayoutState{
		attrs:   attrs
		buffers: buffers
	}

	mut shader_attrs := [16]gfx.ShaderAttrDesc{}
	shader_attrs[0] = gfx.ShaderAttrDesc{
		name:     c'position'
		sem_name: c'POSITION'
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
	unsafe {
		shader_image_sampler_pairs[0] = gfx.ShaderImageSamplerPairDesc{
			used:         true
			image_slot:   0
			sampler_slot: 0
			glsl_name:    glsl_sampler_name
		}
	}
	mut shader_desc := gfx.ShaderDesc{
		attrs: shader_attrs
	}
	$if macos {
		unsafe {
			shader_desc.vs = gfx.ShaderStageDesc{
				source:         vs_src.str
				entry:          vs_entry
				uniform_blocks: ub
			}
			shader_desc.fs = gfx.ShaderStageDesc{
				source:              fs_src.str
				entry:               fs_entry
				images:              shader_images
				samplers:            shader_samplers
				image_sampler_pairs: shader_image_sampler_pairs
			}
		}
	} $else {
		shader_desc.vs = gfx.ShaderStageDesc{
			source:         vs_src.str
			uniform_blocks: ub
		}
		shader_desc.fs = gfx.ShaderStageDesc{
			source:              fs_src.str
			images:              shader_images
			samplers:            shader_samplers
			image_sampler_pairs: shader_image_sampler_pairs
		}
	}

	return sgl.context_make_pipeline(ctx, &gfx.PipelineDesc{
		label:  c'filter_sgl_pip'
		layout: layout
		colors: colors
		shader: gfx.make_shader(&shader_desc)
	})
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
	$if macos {
		window.filter_state.blur_h_pip = make_filter_gfx_pipeline(vs_filter_blur_metal,
			fs_filter_blur_h_metal, c'vs_main', c'fs_main', c'tex')
		window.filter_state.blur_v_pip = make_filter_gfx_pipeline(vs_filter_blur_metal,
			fs_filter_blur_v_metal, c'vs_main', c'fs_main', c'tex')
		window.filter_state.content_pip = make_content_gfx_pipeline(vs_filter_blur_metal,
			fs_filter_color_metal, c'vs_main', c'fs_main')
	} $else {
		window.filter_state.blur_h_pip = make_filter_gfx_pipeline(vs_filter_blur_glsl,
			fs_filter_blur_h_glsl, c'', c'', c'tex_smp')
		window.filter_state.blur_v_pip = make_filter_gfx_pipeline(vs_filter_blur_glsl,
			fs_filter_blur_v_glsl, c'', c'', c'tex_smp')
		window.filter_state.content_pip = make_content_gfx_pipeline(vs_filter_blur_glsl,
			fs_filter_color_glsl, c'', c'')
	}

	// Composite pipeline: SGL (swapchain pass)
	ctx := sgl.default_context()
	$if macos {
		window.filter_state.texture_quad_pip = make_filter_sgl_pipeline(ctx, vs_filter_blur_metal,
			fs_filter_texture_metal, c'vs_main', c'fs_main', c'tex')
	} $else {
		window.filter_state.texture_quad_pip = make_filter_sgl_pipeline(ctx, vs_filter_blur_glsl,
			fs_filter_texture_glsl, c'', c'', c'tex_smp')
	}

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

	color_fmt := gfx.PixelFormat.from(sapp.color_format()) or { gfx.PixelFormat.bgra8 }
	depth_fmt := gfx.PixelFormat.from(sapp.depth_format()) or { gfx.PixelFormat.depth_stencil }

	img_desc := gfx.ImageDesc{
		render_target: true
		width:         w
		height:        h
		pixel_format:  color_fmt
		label:         c'filter_tex'
	}
	tex_a := gfx.make_image(&img_desc)
	tex_b := gfx.make_image(&img_desc)

	// Shared depth buffer (required by default SGL pipeline)
	depth := gfx.make_image(gfx.ImageDesc{
		render_target: true
		width:         w
		height:        h
		pixel_format:  depth_fmt
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
fn draw_filter_quad(x f32, y f32, w f32, h f32) {
	sgl.begin_quads()

	sgl.t2f(0.0, 0.0)
	sgl.v3f(x, y, 0.0)

	sgl.t2f(1.0, 0.0)
	sgl.v3f(x + w, y, 0.0)

	sgl.t2f(1.0, 1.0)
	sgl.v3f(x + w, y + h, 0.0)

	sgl.t2f(0.0, 1.0)
	sgl.v3f(x, y + h, 0.0)

	sgl.end()
}

fn init_image_clip_pipeline(mut window Window) bool {
	if window.pip.image_clip.id != 0 {
		return true
	}
	if window.pip.image_clip_init_failed {
		return false
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
		shader_desc.vs = gfx.ShaderStageDesc{
			source:         vs_metal.str
			entry:          c'vs_main'
			uniform_blocks: ub
		}
		shader_desc.fs = gfx.ShaderStageDesc{
			source:              fs_image_clip_metal.str
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
			source:              fs_image_clip_glsl.str
			images:              shader_images
			samplers:            shader_samplers
			image_sampler_pairs: shader_image_sampler_pairs
		}
	}

	desc := gfx.PipelineDesc{
		label:  c'image_clip_pip'
		colors: colors
		layout: gfx.VertexLayoutState{
			attrs:   attrs
			buffers: buffers
		}
		shader: gfx.make_shader(&shader_desc)
	}

	window.pip.image_clip = sgl.make_pipeline(&desc)
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

	sgl.load_pipeline(window.pip.image_clip)
	sgl.enable_texture()
	sgl.texture(img.simg, img.ssmp)
	sgl.c4b(255, 255, 255, 255)
	draw_quad(x0, y0, w0, h0, z)

	sgl.disable_texture()
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
