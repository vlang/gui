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
    // Unpack radius and thickness.
    // See shaders.v for packing logic.
    float radius = floor(in.params / 1000.0);
    float thickness = fmod(in.params, 1000.0);
    
    // Pixel-independent coordinate system:
    // fwidth gives the change in texture coordinates per pixel.
    // Inverse of this gives pixels per texture coordinate unit.
    float2 width_inv = float2(fwidth(in.uv.x), fwidth(in.uv.y));
    float2 half_size = 1.0 / (width_inv + 1e-6);
    float2 pos = in.uv * half_size;

    // SDF Calculation:
    // Calculate distance to the rounded box boundary.
    float2 q = abs(pos) - half_size + float2(radius);
    float2 max_q = max(q, float2(0.0));
    float d = length(max_q) + min(max(q.x, q.y), 0.0) - radius;

    if (thickness > 0.0) {
        d = abs(d + thickness * 0.5) - thickness * 0.5;
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
    // q: Distance vector from the "corner center"
    float2 q = abs(pos) - half_size + float2(radius + 1.5 * blur);
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;

    // Casting box SDF (clipped shadow region):
    // The casting box is offset by `in.offset` relative to the shadow.
    // This computation masks out the shadow that lies BENEATH the object casting it.
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

const fs_blur_metal = '
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

    float alpha = 1.0 - smoothstep(-blur, blur, d);

    float4 frag_color = float4(in.color.rgb, in.color.a * alpha);

    if (frag_color.a < 0.0) {
        frag_color += tex.sample(smp, in.uv);
    }
    return frag_color;
}
'

const vs_gradient_metal = '
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
    float4 stop1;
    float4 stop2;
    float4 stop3;
    float2 stop_dir;
    float grad_type;
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
    // Pass gradient stops from tm to FS via varyings
    out.stop1 = uniforms.tm[0];
    out.stop2 = uniforms.tm[1];
    out.stop3 = uniforms.tm[2];
    out.stop_dir = uniforms.tm[3].xy;
    out.grad_type = uniforms.tm[3].z;
    return out;
}
'

const fs_gradient_metal = '
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
    float4 color;
    float params;
    float4 stop1;
    float4 stop2;
    float4 stop3;
    float2 stop_dir;
    float grad_type;
};

float random(float2 coords) {
    return fract(sin(dot(coords, float2(12.9898, 78.233))) * 43758.5453);
}

fragment float4 fs_main(VertexOut in [[stage_in]], texture2d<float> tex [[texture(0)]], sampler smp [[sampler(0)]]) {
    float radius = floor(in.params / 1000.0);

    // SDF clipping for rounded rect
    float2 width_inv = float2(fwidth(in.uv.x), fwidth(in.uv.y));
    float2 half_size = 1.0 / (width_inv + 1e-6);
    float2 pos = in.uv * half_size;

    float2 q = abs(pos) - half_size + float2(radius);
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;

    float grad_len = length(float2(dfdx(d), dfdy(d)));
    d = d / max(grad_len, 0.001);
    float sdf_alpha = 1.0 - smoothstep(-0.59, 0.59, d);

    // Unified gradient t calculation
    float t;
    if (in.grad_type > 0.5) {
        // Radial: distance from center with aspect correction
        float2 aspect = in.stop_dir;
        t = length(in.uv * aspect);
    } else {
        // Linear: project onto direction vector
        float2 dir = in.stop_dir;
        t = dot(in.uv, dir) * 0.5 + 0.5;
    }
    t = clamp(t, 0.0, 1.0);

    // Read gradient stops from varyings (passed from VS)
    float4 stop1 = in.stop1;
    float4 stop2 = in.stop2;
    float4 stop3 = in.stop3;

    // Multi-stop interpolation
    float4 gradient_color;
    float4 c1, c2;
    float local_t;

    if (t <= stop2.w) {
        c1 = stop1;
        c2 = stop2;
        local_t = (t - stop1.w) / max(stop2.w - stop1.w, 0.0001);
    } else {
        c1 = stop2;
        c2 = stop3;
        local_t = (t - stop2.w) / max(stop3.w - stop2.w, 0.0001);
    }

    // Premultiplied alpha interpolation (CSS spec)
    // Currently stops are packed as (r,g,b,position), alpha=1.0
    // Structure ready for alpha support when stop format extended
    float c1_alpha = 1.0;  // TODO: read from extended stop format
    float c2_alpha = 1.0;
    float3 c1_pre = c1.rgb * c1_alpha;
    float3 c2_pre = c2.rgb * c2_alpha;
    float3 rgb_pre = mix(c1_pre, c2_pre, local_t);
    float alpha = mix(c1_alpha, c2_alpha, local_t);
    float3 rgb = rgb_pre / max(alpha, 0.0001f);
    gradient_color = float4(rgb, alpha);

    // Add dithering to prevent color banding
    float dither = (random(in.position.xy) - 0.5) / 255.0;
    gradient_color.rgb += float3(dither);

    // Combine gradient with SDF clipping
    float4 frag_color = float4(gradient_color.rgb, gradient_color.a * sdf_alpha);

    // sgl workaround: dummy texture sample
    if (frag_color.a < 0.0) {
        frag_color += tex.sample(smp, in.uv);
    }
    return frag_color;
}
'
