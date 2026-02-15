module gui

// --- GLSL Shader Sources (OpenGL 3.3) ---

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
        // Pass unpacked z-coordinate as "params" to fragment shader.
        // Rasterizer will interpolate this, but since it is constant per quad,
        // it acts as a flat uniform per-primitive.
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
        // Unpack radius and thickness from the float parameter.
        // Example: params = 5002.0 -> Radius=5.0, Thickness=2.0.
        float radius = floor(params / 1000.0);
        float thickness = mod(params, 1000.0);

        // UV and Pixel Conversion
        // fwidth() calculates the rate of change of the UV coordinates relative to screen pixels.
        // fwidth(uv.x) gives the change in u per horizontal pixel step.
        // Inverse of this value yields the number of pixels per UV unit.
        vec2 uv_to_px = 1.0 / (vec2(fwidth(uv.x), fwidth(uv.y)) + 1e-6);
        vec2 half_size = uv_to_px;  // Since UV is -1..1, the total size is 2.0 UV units. half-size in UV = 1.0. 1.0 UV * uv_to_px = half size in pixels.
        vec2 pos = uv * half_size;  // Map current UV to pixel coordinates relative to center (0,0).

        // SDF (Signed Distance Field) Calculation for Rounded Box
        // q calculates the vector from the corner "core" (inner rectangle for the rounded corners).
        // abs(pos) folds all 4 quadrants into one.
        // - half_size + radius: shifts origin to the corner center.
        vec2 q = abs(pos) - half_size + vec2(radius);
        
        // d is the distance to the rounded edge.
        // length(max(q, 0.0)): Distance from the corner center to the query point (for outside corner).
        // min(max(q.x, q.y), 0.0): inner distance correction.
        // - radius: Subtract radius to get surface distance.
        float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;

        if (thickness > 0.0) {
            d = abs(d + thickness * 0.5) - thickness * 0.5;
        }

        // Normalize by gradient length for uniform anti-aliasing
        float grad_len = length(vec2(dFdx(d), dFdy(d)));
        d = d / max(grad_len, 0.001);
        float alpha = 1.0 - smoothstep(-0.59, 0.59, d);
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

const vs_shadow_glsl = '
    #version 330
    layout(location=0) in vec3 position;
    layout(location=1) in vec2 texcoord0;
    layout(location=2) in vec4 color0;

    uniform mat4 mvp;
    uniform mat4 tm; // Texture matrix

    out vec2 uv;
    out vec4 color;
    out float params; // z stores packed radius and blur
    out vec2 offset;

    void main() {
        gl_Position = mvp * vec4(position.xy, 0.0, 1.0);
        uv = texcoord0;
        color = color0;
        params = position.z;
        offset = (tm * vec4(0,0,0,1)).xy; // Extract translation
    }
'

const fs_shadow_glsl = '
    #version 330
    uniform sampler2D tex;
    in vec2 uv;
    in vec4 color;
    in float params;
    in vec2 offset;

    out vec4 frag_color;

    void main() {
        float radius = floor(params / 1000.0);
        float blur = mod(params, 1000.0);

        vec2 uv_to_px = 1.0 / (vec2(fwidth(uv.x), fwidth(uv.y)) + 1e-6);
        vec2 half_size = uv_to_px;
        vec2 pos = uv * half_size;

        // SDF for rounded box
        vec2 q = abs(pos) - half_size + vec2(radius + 1.5 * blur);
        float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;

        // SDF for casting box (using offset)
        vec2 q_c = abs(pos + offset) - half_size + vec2(radius + 1.5 * blur);
        float d_c = length(max(q_c, 0.0)) + min(max(q_c.x, q_c.y), 0.0) - radius;

        // Shadow logic:
        // alpha_falloff: Smooth transition from 0 (inside) to blur radius (outside).
        // Inverted (1.0 - ...) so opacity is 1 inside the shadow and 0 outside.
        float alpha_falloff = 1.0 - smoothstep(0.0, max(1.0, blur), d);
        
        // alpha_clip: The shadow should not be visible *under* the casting object.
        // d_c < 0 means the fragment is inside the casting box.
        // Shadow fades out where d_c < 0 (inside casting box).
        float alpha_clip = smoothstep(-1.0, 0.0, d_c); // Hard fade at casting edge

        float alpha = alpha_falloff * alpha_clip;

        frag_color = vec4(color.rgb, color.a * alpha);

        if (frag_color.a < 0.0) {
            frag_color += texture(tex, uv);
        }
    }
'

const fs_blur_glsl = '
    #version 330
    uniform sampler2D tex;
    in vec2 uv;
    in vec4 color;
    in float params;
    in vec2 offset;

    out vec4 frag_color;

    void main() {
        float radius = floor(params / 1000.0);
        float blur = mod(params, 1000.0);

        vec2 uv_to_px = 1.0 / (vec2(fwidth(uv.x), fwidth(uv.y)) + 1e-6);
        vec2 half_size = uv_to_px;
        vec2 pos = uv * half_size;

        vec2 q = abs(pos) - half_size + vec2(radius + 1.5 * blur);
        float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;

        float alpha = 1.0 - smoothstep(-blur, blur, d);

        frag_color = vec4(color.rgb, color.a * alpha);

        if (frag_color.a < 0.0) {
            frag_color += texture(tex, uv);
        }
    }
'

const vs_gradient_glsl = '
    #version 330
    layout(location=0) in vec3 position;
    layout(location=1) in vec2 texcoord0;
    layout(location=2) in vec4 color0;

    uniform mat4 mvp;
    uniform mat4 tm;

    out vec2 uv;
    out vec4 color;
    out float params;
    out vec4 stop12;
    out vec4 stop34;
    out vec4 stop56;
    out vec4 meta;

    void main() {
        gl_Position = mvp * vec4(position.xy, 0.0, 1.0);
        uv = texcoord0;
        color = color0;
        params = position.z;
        stop12 = tm[0];
        stop34 = tm[1];
        stop56 = tm[2];
        meta = tm[3];
    }
'

const fs_gradient_glsl = '
    #version 330
    uniform sampler2D tex;
    in vec2 uv;
    in vec4 color;
    in float params;
    in vec4 stop12;
    in vec4 stop34;
    in vec4 stop56;
    in vec4 meta;

    out vec4 frag_color;

    float random(vec2 coords) {
        return fract(sin(dot(coords.xy, vec2(12.9898,78.233))) * 43758.5453);
    }

    void unpack_gradient_data(float val1, float val2, out vec4 c, out float p) {
        float r = mod(val1, 256.0);
        float g = mod(floor(val1 / 256.0), 256.0);
        float b = floor(val1 / 65536.0);
        
        float a = mod(val2, 256.0);
        p = floor(val2 / 256.0) / 10000.0;
        
        c = vec4(r/255.0, g/255.0, b/255.0, a/255.0);
    }

    void main() {
        float radius = floor(params / 1000.0);

        // Metadata extraction
        float hw = meta.x;
        float hh = meta.y;
        float grad_type = meta.z;
        int stop_count = int(meta.w);

        // Pixel-based position from UV
        vec2 pos = uv * vec2(hw, hh);

        // SDF clipping for rounded rect (using passed dimensions)
        vec2 q = abs(pos) - vec2(hw, hh) + vec2(radius);
        float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;

        // Anti-aliasing (d is already in pixel units)
        float sdf_alpha = 1.0 - smoothstep(-0.5, 0.5, d);

        // Unified gradient t calculation
        float t;
        if (grad_type > 0.5) {
            float target_radius = stop56.w; // Packed in tm_data[11]
            t = length(pos) / target_radius;
        } else {
            vec2 stop_dir = vec2(stop56.z, stop56.w); // tm_data[10, 11]
            t = dot(uv, stop_dir) * 0.5 + 0.5;
        }
        t = clamp(t, 0.0, 1.0);

        // Unpack stops (up to 5 fully supported with metadata packing)
        vec4 stop_colors[6];
        float stop_positions[6];

        unpack_gradient_data(stop12.x, stop12.y, stop_colors[0], stop_positions[0]);
        unpack_gradient_data(stop12.z, stop12.w, stop_colors[1], stop_positions[1]);
        unpack_gradient_data(stop34.x, stop34.y, stop_colors[2], stop_positions[2]);
        unpack_gradient_data(stop34.z, stop34.w, stop_colors[3], stop_positions[3]);
        unpack_gradient_data(stop56.x, stop56.y, stop_colors[4], stop_positions[4]);
        // Stop 6 slot partially used for metadata, but we only have 5 stops in demo
        stop_colors[5] = stop_colors[4]; stop_positions[5] = stop_positions[4];

        // Multi-stop interpolation loop
        vec4 c1 = stop_colors[0];
        vec4 c2 = c1;
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

        float local_t = (t - p1) / max(p2 - p1, 0.0001);

        // Premultiplied alpha interpolation (CSS spec)
        vec3 c1_pre = c1.rgb * c1.a;
        vec3 c2_pre = c2.rgb * c2.a;
        vec3 rgb_pre = mix(c1_pre, c2_pre, local_t);
        float alpha = mix(c1.a, c2.a, local_t);
        vec3 rgb = rgb_pre / max(alpha, 0.0001);
        vec4 gradient_color = vec4(rgb, alpha);

        // Add dithering to prevent color banding
        float dither = (random(gl_FragCoord.xy) - 0.5) / 255.0;
        gradient_color.rgb += vec3(dither);

        // Combine gradient with SDF clipping and vertex opacity
        frag_color = vec4(gradient_color.rgb, gradient_color.a * sdf_alpha * color.a);

        // sgl workaround: dummy texture sample
        if (frag_color.a < 0.0) {
            frag_color += texture(tex, uv);
        }
    }
'

const vs_custom_glsl = '
    #version 330
    layout(location=0) in vec3 position;
    layout(location=1) in vec2 texcoord0;
    layout(location=2) in vec4 color0;

    uniform mat4 mvp;
    uniform mat4 tm;

    out vec2 uv;
    out vec4 color;
    out float params;
    out vec4 p0;
    out vec4 p1;
    out vec4 p2;
    out vec4 p3;

    void main() {
        gl_Position = mvp * vec4(position.xy, 0.0, 1.0);
        uv = texcoord0;
        color = color0;
        params = position.z;
        p0 = tm[0];
        p1 = tm[1];
        p2 = tm[2];
        p3 = tm[3];
    }
'

// --- Offscreen Gaussian blur shaders for SVG filters ---

const vs_filter_blur_glsl = '
    #version 330
    layout(location=0) in vec3 position;
    layout(location=1) in vec2 texcoord0;
    layout(location=2) in vec4 color0;

    uniform mat4 mvp;
    uniform mat4 tm;

    out vec2 uv;
    out vec4 color;
    out float std_dev;

    void main() {
        gl_Position = mvp * vec4(position.xy, 0.0, 1.0);
        uv = texcoord0;
        color = color0;
        std_dev = tm[0][0];
    }
'

const fs_filter_blur_h_glsl = '
    #version 330
    uniform sampler2D tex_smp;
    in vec2 uv;
    in vec4 color;
    in float std_dev;

    out vec4 frag_color;

    void main() {
        // Normalized Gaussian weights for sigma=1, 13 taps
        float w[7] = float[7](0.19947, 0.17603, 0.12098, 0.06476, 0.02700, 0.00877, 0.00222);
        vec2 tex_size = vec2(textureSize(tex_smp, 0));
        float step_size = std_dev / tex_size.x;

        frag_color = texture(tex_smp, uv) * w[0];
        for (int i = 1; i < 7; i++) {
            float off = float(i) * step_size;
            frag_color += texture(tex_smp, uv + vec2(off, 0.0)) * w[i];
            frag_color += texture(tex_smp, uv - vec2(off, 0.0)) * w[i];
        }
    }
'

const fs_filter_blur_v_glsl = '
    #version 330
    uniform sampler2D tex_smp;
    in vec2 uv;
    in vec4 color;
    in float std_dev;

    out vec4 frag_color;

    void main() {
        float w[7] = float[7](0.19947, 0.17603, 0.12098, 0.06476, 0.02700, 0.00877, 0.00222);
        vec2 tex_size = vec2(textureSize(tex_smp, 0));
        float step_size = std_dev / tex_size.y;

        frag_color = texture(tex_smp, uv) * w[0];
        for (int i = 1; i < 7; i++) {
            float off = float(i) * step_size;
            frag_color += texture(tex_smp, uv + vec2(0.0, off)) * w[i];
            frag_color += texture(tex_smp, uv - vec2(0.0, off)) * w[i];
        }
    }
'

// Color pass-through for offscreen content (no texture).
const fs_filter_color_glsl = '
    #version 330
    in vec2 uv;
    in vec4 color;
    in float std_dev;

    out vec4 frag_color;

    void main() {
        frag_color = color;
    }
'

const fs_filter_texture_glsl = '
    #version 330
    uniform sampler2D tex_smp;
    in vec2 uv;
    in vec4 color;
    in float std_dev;

    out vec4 frag_color;

    void main() {
        frag_color = texture(tex_smp, uv) * color;
    }
'
