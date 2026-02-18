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
    // Unpack 12-bit fixed-point radius/thickness (quarter-pixel precision).
    float radius = floor(in.params / 4096.0) / 4.0;
    float thickness = fmod(in.params, 4096.0) / 4.0;
    
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
    float radius = floor(in.params / 4096.0) / 4.0;
    float blur = fmod(in.params, 4096.0) / 4.0;

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
    float radius = floor(in.params / 4096.0) / 4.0;
    float blur = fmod(in.params, 4096.0) / 4.0;

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
    float4 stop12;
    float4 stop34;
    float4 stop56;
    float4 meta;
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
    // Pass packed gradient data to FS via varyings
    out.stop12 = uniforms.tm[0];
    out.stop34 = uniforms.tm[1];
    out.stop56 = uniforms.tm[2];
    out.meta = uniforms.tm[3];
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
    float4 stop12;
    float4 stop34;
    float4 stop56;
    float4 meta;
};

float random(float2 coords) {
    return fract(sin(dot(coords, float2(12.9898, 78.233))) * 43758.5453);
}

void unpack_gradient_data(float val1, float val2, thread float4& c, thread float& p) {
    float r = fmod(val1, 256.0);
    float g = fmod(floor(val1 / 256.0), 256.0);
    float b = floor(val1 / 65536.0);
    
    float a = fmod(val2, 256.0);
    p = floor(val2 / 256.0) / 10000.0;
    
    c = float4(r/255.0, g/255.0, b/255.0, a/255.0);
}

fragment float4 fs_main(VertexOut in [[stage_in]], texture2d<float> tex [[texture(0)]], sampler smp [[sampler(0)]]) {
    float radius = floor(in.params / 4096.0) / 4.0;

    // Metadata extraction
    float hw = in.meta.x;
    float hh = in.meta.y;
    float grad_type = in.meta.z;
    int stop_count = int(in.meta.w);

    // Pixel-based position from UV
    float2 pos = in.uv * float2(hw, hh);

    // SDF clipping for rounded rect (using passed dimensions)
    float2 q = abs(pos) - float2(hw, hh) + float2(radius);
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;

    float grad_len = length(float2(dfdx(d), dfdy(d)));
    d = d / max(grad_len, 0.001);
    float sdf_alpha = 1.0 - smoothstep(-0.59, 0.59, d);

    // Unified gradient t calculation
    float t;
    if (grad_type > 0.5) {
        float target_radius = in.stop56.w; // Packed in tm_data[11]
        t = length(pos) / target_radius;
    } else {
        float2 stop_dir = float2(in.stop56.z, in.stop56.w); // tm_data[10, 11]
        t = dot(in.uv, stop_dir) * 0.5 + 0.5;
    }
    t = clamp(t, 0.0, 1.0);

    // Unpack stops (up to 5 fully supported with metadata packing)
    float4 stop_colors[6];
    float stop_positions[6];

    unpack_gradient_data(in.stop12.x, in.stop12.y, stop_colors[0], stop_positions[0]);
    unpack_gradient_data(in.stop12.z, in.stop12.w, stop_colors[1], stop_positions[1]);
    unpack_gradient_data(in.stop34.x, in.stop34.y, stop_colors[2], stop_positions[2]);
    unpack_gradient_data(in.stop34.z, in.stop34.w, stop_colors[3], stop_positions[3]);
    unpack_gradient_data(in.stop56.x, in.stop56.y, stop_colors[4], stop_positions[4]);
    // Stop 6 slot partially used for metadata
    stop_colors[5] = stop_colors[4]; stop_positions[5] = stop_positions[4];

    // Multi-stop interpolation loop
    float4 c1 = stop_colors[0];
    float4 c2 = c1;
    float p1 = stop_positions[0];
    float p2 = p1;

    for (int i = 1; i < 6; i++) {
        if (i >= stop_count) break;
        if (t <= stop_positions[i]) {
            c2 = stop_colors[i];
            p2 = stop_positions[i];
            c1 = stop_colors[i-1];
            p1 = stop_positions[i-1];
            break;
        }
        if (i == stop_count - 1) {
            c1 = stop_colors[i];
            c2 = c1;
            p1 = stop_positions[i];
            p2 = p1;
        }
    }

    float local_t = (t - p1) / max(p2 - p1, 0.0001f);

    // Premultiplied alpha interpolation (CSS spec)
    float3 c1_pre = c1.rgb * c1.a;
    float3 c2_pre = c2.rgb * c2.a;
    float3 rgb_pre = mix(c1_pre, c2_pre, local_t);
    float alpha = mix(c1.a, c2.a, local_t);
    float3 rgb = rgb_pre / max(alpha, 0.0001f);
    float4 gradient_color = float4(rgb, alpha);

    // Add dithering to prevent color banding
    float dither = (random(in.position.xy) - 0.5) / 255.0;
    gradient_color.rgb += float3(dither);

    // Combine gradient with SDF clipping and vertex opacity
    float4 frag_color = float4(gradient_color.rgb, gradient_color.a * sdf_alpha * in.color.a);

    // sgl workaround: dummy texture sample
    if (frag_color.a < 0.0) {
        frag_color += tex.sample(smp, in.uv);
    }
    return frag_color;
}
'

const vs_custom_metal = '
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
    float4 p0;
    float4 p1;
    float4 p2;
    float4 p3;
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
    out.p0 = uniforms.tm[0];
    out.p1 = uniforms.tm[1];
    out.p2 = uniforms.tm[2];
    out.p3 = uniforms.tm[3];
    return out;
}
'

// --- Offscreen Gaussian blur shaders for SVG filters ---

// Passthrough vertex shader for texture-based blur passes.
// UVs map 0..1 for texture sampling. tm[0][0] carries stdDeviation.
const vs_filter_blur_metal = '
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
    float std_dev;
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
    out.std_dev = uniforms.tm[0][0];
    return out;
}
'

// 13-tap horizontal Gaussian blur fragment shader.
// Weights precomputed for sigma=1, scaled by stdDeviation via step size.
const fs_filter_blur_h_metal = '
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
    float4 color;
    float std_dev;
};

fragment float4 fs_main(VertexOut in [[stage_in]], texture2d<float> tex [[texture(0)]], sampler smp [[sampler(0)]]) {
    // Normalized Gaussian weights for sigma=1, 13 taps
    const float w[7] = { 0.19947, 0.17603, 0.12098, 0.06476, 0.02700, 0.00877, 0.00222 };
    float step = in.std_dev / float(tex.get_width());

    float4 c = tex.sample(smp, in.uv) * w[0];
    for (int i = 1; i < 7; i++) {
        float off = float(i) * step;
        c += tex.sample(smp, in.uv + float2(off, 0.0)) * w[i];
        c += tex.sample(smp, in.uv - float2(off, 0.0)) * w[i];
    }
    return c;
}
'

// 13-tap vertical Gaussian blur fragment shader.
const fs_filter_blur_v_metal = '
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
    float4 color;
    float std_dev;
};

fragment float4 fs_main(VertexOut in [[stage_in]], texture2d<float> tex [[texture(0)]], sampler smp [[sampler(0)]]) {
    const float w[7] = { 0.19947, 0.17603, 0.12098, 0.06476, 0.02700, 0.00877, 0.00222 };
    float step = in.std_dev / float(tex.get_height());

    float4 c = tex.sample(smp, in.uv) * w[0];
    for (int i = 1; i < 7; i++) {
        float off = float(i) * step;
        c += tex.sample(smp, in.uv + float2(0.0, off)) * w[i];
        c += tex.sample(smp, in.uv - float2(0.0, off)) * w[i];
    }
    return c;
}
'

// Simple color pass-through shader for rendering SVG content
// to offscreen texture (no texture sampling).
const fs_filter_color_metal = '
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
    float4 color;
    float std_dev;
};

fragment float4 fs_main(VertexOut in [[stage_in]]) {
    return in.color;
}
'

// Simple texture sampling shader for compositing blurred result.
const fs_filter_texture_metal = '
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
    float4 color;
    float std_dev;
};

fragment float4 fs_main(VertexOut in [[stage_in]], texture2d<float> tex [[texture(0)]], sampler smp [[sampler(0)]]) {
    return tex.sample(smp, in.uv) * in.color;
}
'
