module gui

// The `render_shader.v` module provides high-performance rendering primitives for
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

// --- Shader Sources ---

// GLSL 330
const vs_glsl = '
    #version 330
    layout(location=0) in vec3 position;
    layout(location=1) in vec2 texcoord0;
    layout(location=2) in vec4 color0;

    uniform mat4 mvp;

    out vec2 uv;
    out vec4 color;
    out float params; // z stores packed radius and thickness

    void main() {
        gl_Position = mvp * vec4(position.xy, 0.0, 1.0);
        uv = texcoord0;
        color = color0;
        params = position.z;
    }
'

const fs_glsl = '
    #version 330
    uniform sampler2D tex;
    in vec2 uv;
    in vec4 color;
    in float params;

    out vec4 frag_color;

    void main() {
        float radius = floor(params / 1000.0);
        float thickness = mod(params, 1000.0);

        // Use fwidth to get pixel size in UV space, then convert UV to pixels
        vec2 uv_to_px = 1.0 / (vec2(fwidth(uv.x), fwidth(uv.y)) + 1e-6);
        vec2 half_size = uv_to_px;  // half size in pixels (since UV spans -1 to 1)
        vec2 pos = uv * half_size;  // position in pixels from center

        // SDF for rounded rectangle
        vec2 q = abs(pos) - half_size + vec2(radius);
        float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;

        if (thickness > 0.0) {
            // Reduce thickness at corners to compensate for arc coverage
            float corner = 0.0;
            if (radius > 0.0) {
                corner = smoothstep(0.0, radius * 0.5, min(q.x, q.y));
            }
            float adj_thickness = mix(thickness, thickness * 0.7, corner);
            d = abs(d) - adj_thickness * 0.5;
        }

        // Normalize by gradient length for uniform anti-aliasing
        float grad_len = length(vec2(dFdx(d), dFdy(d)));
        d = d / max(grad_len, 0.001);
        float alpha = 1.0 - smoothstep(-0.5, 0.5, d);
        frag_color = vec4(color.rgb, color.a * alpha);
        
        // sgl workaround: dummy texture sample
        // sgl.h always binds a texture/sampler, so we must declare them to avoid validation errors.
        // We use a condition that is always false (alpha < 0.0) to ensure the sample is never
        // actually executed while preventing the compiler from optimizing away the bindings.
        if (frag_color.a < 0.0) {
            frag_color += texture(tex, uv);
        }
    }
'

// Metal Shader Source (MSL)
const vs_metal = '
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float2 texcoord0 [[attribute(1)]];
    float4 color0 [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
    float4 color;
    float params;
};

struct Uniforms {
    float4x4 mvp;
};

vertex VertexOut vs_main(VertexIn in [[stage_in]], constant Uniforms &uniforms [[buffer(0)]]) {
    VertexOut out;
    out.position = uniforms.mvp * float4(in.position.xy, 0.0, 1.0);
    out.uv = in.texcoord0;
    out.color = in.color0;
    out.params = in.position.z;
    return out;
}
'

const fs_metal = '
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
    float4 color;
    float params;
};

fragment float4 fs_main(VertexOut in [[stage_in]], texture2d<float> tex [[texture(0)]], sampler smp [[sampler(0)]]) {
    float radius = floor(in.params / 1000.0);
    float thickness = fmod(in.params, 1000.0);
    
    float2 width_inv = float2(fwidth(in.uv.x), fwidth(in.uv.y));
    float2 half_size = 1.0 / (width_inv + 1e-6);
    float2 pos = in.uv * half_size;

    float2 q = abs(pos) - half_size + float2(radius);
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;

    if (thickness > 0.0) {
        // Reduce thickness at corners to compensate for arc coverage
        float corner = 0.0;
        if (radius > 0.0) {
             corner = smoothstep(0.0, radius * 0.5, min(q.x, q.y));
        }
        float adj_thickness = mix(thickness, thickness * 0.7, corner);
        d = abs(d) - adj_thickness * 0.5;
    }

    // Normalize by gradient length for uniform anti-aliasing
    float grad_len = length(float2(dfdx(d), dfdy(d)));
    d = d / max(grad_len, 0.001);
    float alpha = 1.0 - smoothstep(-0.5, 0.5, d);
    float4 frag_color = float4(in.color.rgb, in.color.a * alpha);
    
    // sgl workaround: dummy texture sample
    // sgl.h always binds a texture/sampler, so we must declare them to avoid validation errors.
    // We use a condition that is always false (alpha < 0.0) to ensure the sample is never
    // actually executed while preventing the compiler from optimizing away the bindings.
    if (frag_color.a < 0.0) {
        frag_color += tex.sample(smp, in.uv);
    }
    return frag_color;
}
'

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

// --- Public API ---

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
