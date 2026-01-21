module gui

// The `xtra_render.v` module provides high-performance rendering primitives for
// rounded rectangles, using signed distance field (SDF) shaders via sokol.sgl.
// This replaces the previous discrete triangle implementation.
import gg
import sokol.sgl
import sokol.gfx

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
    in vec2 uv;
    in vec4 color;
    in float params;

    uniform sampler2D tex;

    out vec4 frag_color;

    void main() {
        float thickness = floor(params / 10000.0);
        float radius = mod(params, 10000.0);

        // Dummy sample to keep uniform active
        vec4 dummy = texture(tex, uv);

        vec2 width_inv = vec2(fwidth(uv.x), fwidth(uv.y));
        vec2 half_size = 1.0 / (width_inv + 1e-6);
        vec2 pos = uv * half_size;

        vec2 q = abs(pos) - half_size + vec2(radius);
        float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;

        if (thickness > 0.0) {
            d = abs(d) - thickness * 0.5;
        }

        float alpha = 1.0 - smoothstep(-0.5, 0.5, d);
        frag_color = vec4(color.rgb, color.a * alpha) + dummy * 0.00001;
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
    float thickness = floor(in.params / 10000.0);
    float radius = fmod(in.params, 10000.0);
    
    float4 dummy = tex.sample(smp, in.uv);

    float2 width_inv = float2(fwidth(in.uv.x), fwidth(in.uv.y));
    float2 half_size = 1.0 / (width_inv + 1e-6);
    float2 pos = in.uv * half_size;

    float2 q = abs(pos) - half_size + float2(radius);
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;

    if (thickness > 0.0) {
        d = abs(d) - thickness * 0.5;
    }

    float alpha = 1.0 - smoothstep(-0.5, 0.5, d);
    return float4(in.color.rgb, in.color.a * alpha) + dummy * 0.00001;
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
		type:        .mat4
		array_count: 1
	}
	ub_uniforms[1] = gfx.ShaderUniformDesc{
		name:        c'tm'
		type:        .mat4
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

	// Images and Samplers
	mut images := [12]gfx.ShaderImageDesc{}
	images[0] = gfx.ShaderImageDesc{
		used:        true
		image_type:  ._2d
		sample_type: .float
	}

	mut samplers := [8]gfx.ShaderSamplerDesc{}
	samplers[0] = gfx.ShaderSamplerDesc{
		used:         true
		sampler_type: .filtering
	}

	mut pairs := [12]gfx.ShaderImageSamplerPairDesc{}
	pairs[0] = gfx.ShaderImageSamplerPairDesc{
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
			images:              images
			samplers:            samplers
			image_sampler_pairs: pairs
		}
	} $else {
		shader_desc.vs = gfx.ShaderStageDesc{
			source:         vs_glsl.str
			uniform_blocks: ub
		}
		shader_desc.fs = gfx.ShaderStageDesc{
			source:              fs_glsl.str
			images:              images
			samplers:            samplers
			image_sampler_pairs: pairs
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

	// Ensure no lingering textures from gg
	sgl.disable_texture()
	sgl.load_pipeline(window.rounded_rect_pip)

	sgl.c4b(c.r, c.g, c.b, c.a)

	z_val := r // thickness 0

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

	// Ensure no lingering textures from gg
	sgl.disable_texture()
	sgl.load_pipeline(window.rounded_rect_pip)
	sgl.c4b(c.r, c.g, c.b, c.a)

	// Pack parameters: r + thickness * 10000
	thickness := f32(1.0) * scale
	z_val := r + (thickness * 10000.0)

	draw_quad(sx, sy, sw, sh, z_val)
}

fn draw_quad(x f32, y f32, w f32, h f32, z f32) {
	sgl.begin_quads()

	// Use UV -1.0 to 1.0 range

	// Top Left
	sgl.v3f(x, y, z)
	sgl.t2f(-1.0, -1.0)

	// Top Right
	sgl.v3f(x + w, y, z)
	sgl.t2f(1.0, -1.0)

	// Bottom Right
	sgl.v3f(x + w, y + h, z)
	sgl.t2f(1.0, 1.0)

	// Bottom Left
	sgl.v3f(x, y + h, z)
	sgl.t2f(-1.0, 1.0)

	sgl.end()
}
