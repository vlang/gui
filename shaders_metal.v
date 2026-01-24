module gui

// --- Metal Shader Sources (MSL) ---

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
    float4x4 tm;
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
    float2 max_q = max(q, float2(0.0));
    float d = length(max_q) + min(max(q.x, q.y), 0.0) - radius;

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
    float alpha = 1.0 - smoothstep(-0.59, 0.59, d);
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

const vs_shadow_metal = '
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
    float2 offset;
};

struct Uniforms {
    float4x4 mvp;
    float4x4 tm;
};


vertex VertexOut vs_main(VertexIn in [[stage_in]], constant Uniforms &uniforms [[buffer(0)]]) {
    VertexOut out;
    out.position = uniforms.mvp * float4(in.position.xy, 0.0, 1.0);
    out.uv = in.texcoord0;
    out.color = in.color0;
    out.params = in.position.z;
    out.offset = uniforms.tm[3].xy;
    return out;
}
'

const fs_shadow_metal = '
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
    float4 color;
    float params;
    float2 offset;
};

fragment float4 fs_main(VertexOut in [[stage_in]], texture2d<float> tex [[texture(0)]], sampler smp [[sampler(0)]]) {
    float radius = floor(in.params / 1000.0);
    float blur = fmod(in.params, 1000.0);

    float2 width_inv = float2(fwidth(in.uv.x), fwidth(in.uv.y));
    float2 half_size = 1.0 / (width_inv + 1e-6);
    float2 pos = in.uv * half_size;

    // SDF for rounded box
    float2 q = abs(pos) - half_size + float2(radius + 1.5 * blur);
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;

    // Casting box SDF (clipped shadow region):
    // The casting box is offset by `in.offset` relative to the shadow.
    // Casting box center relative to pos is `in.offset`.
    float2 q_c = abs(pos + in.offset) - half_size + float2(radius + 1.5 * blur);
    float d_c = length(max(q_c, 0.0)) + min(max(q_c.x, q_c.y), 0.0) - radius;

    // Shadow logic:
    // Clip inner shadow (d < 0) regarding casting box to prevent bleeding.
    float alpha_falloff = 1.0 - smoothstep(0.0, max(1.0, blur), d);
    float alpha_clip = smoothstep(-1.0, 0.0, d_c); // Hard fade at casting edge

    float alpha = alpha_falloff * alpha_clip;

    float4 frag_color = float4(in.color.rgb, in.color.a * alpha);

    if (frag_color.a < 0.0) {
        frag_color += tex.sample(smp, in.uv);
    }
    return frag_color;
}
'
