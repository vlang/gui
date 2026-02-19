module gui

// shader.v defines the Shader struct and helper functions for
// custom fragment shader support. Users write only the color
// computation body; the framework wraps it with struct defs,
// SDF round-rect clipping, and the sgl dummy texture workaround.

@[heap]
pub struct Shader {
pub:
	metal  string // MSL fragment body
	glsl   string // GLSL 3.3 fragment body
	params []f32  // up to 16 custom floats → tm matrix
}

// build_metal_fragment wraps a user-supplied MSL body with the
// standard preamble (struct defs, SDF clipping) and epilogue
// (dummy texture sample, return).
fn build_metal_fragment(body string) string {
	return '
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
    float4 color;
    float params;
    float4 p0;
    float4 p1;
    float4 p2;
    float4 p3;
};

fragment float4 fs_main(VertexOut in [[stage_in]], texture2d<float> tex [[texture(0)]], sampler smp [[sampler(0)]]) {
    float radius = floor(in.params / 4096.0) / 4.0;

    float2 width_inv = float2(fwidth(in.uv.x), fwidth(in.uv.y));
    float2 half_size = 1.0 / (width_inv + 1e-6);
    float2 pos = in.uv * half_size;

    float2 q = abs(pos) - half_size + float2(radius);
    float2 max_q = max(q, float2(0.0));
    float d = length(max_q) + min(max(q.x, q.y), 0.0) - radius;

    float grad_len = length(float2(dfdx(d), dfdy(d)));
    d = d / max(grad_len, 0.001);
    float sdf_alpha = 1.0 - smoothstep(-0.59, 0.59, d);

    // --- user body ---
    ${body}
    // --- end user body ---

    frag_color = float4(frag_color.rgb, frag_color.a * sdf_alpha);

    if (frag_color.a < 0.0) {
        frag_color += tex.sample(smp, in.uv);
    }
    return frag_color;
}
'
}

// build_glsl_fragment wraps a user-supplied GLSL body with the
// standard preamble and epilogue.
fn build_glsl_fragment(body string) string {
	return '
    #version 330
    uniform sampler2D tex;
    in vec2 uv;
    in vec4 color;
    in float params;
    in vec4 p0;
    in vec4 p1;
    in vec4 p2;
    in vec4 p3;

    out vec4 _frag_out;

    void main() {
        float radius = floor(params / 4096.0) / 4.0;

        vec2 uv_to_px = 1.0 / (vec2(fwidth(uv.x), fwidth(uv.y)) + 1e-6);
        vec2 half_size = uv_to_px;
        vec2 pos = uv * half_size;

        vec2 q = abs(pos) - half_size + vec2(radius);
        float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;

        float grad_len = length(vec2(dFdx(d), dFdy(d)));
        d = d / max(grad_len, 0.001);
        float sdf_alpha = 1.0 - smoothstep(-0.59, 0.59, d);

        // --- user body ---
        ${body}
        // --- end user body ---

        _frag_out = vec4(frag_color.rgb, frag_color.a * sdf_alpha);

        if (_frag_out.a < 0.0) {
            _frag_out += texture(tex, uv);
        }
    }
'
}

// shader_hash computes a cache key from the shader source.
fn shader_hash(shader &Shader) u64 {
	$if macos {
		return hash_string(shader.metal)
	} $else {
		return hash_string(shader.glsl)
	}
}

// hash_string computes a 64-bit FNV-1a hash of a string.
fn hash_string(s string) u64 {
	mut h := u64(0xcbf29ce484222325)
	for c in s {
		h = h ^ u64(c)
		h = h * u64(0x100000001b3)
	}
	return h
}
