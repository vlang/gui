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
    out vec4 stop1;
    out vec4 stop2;
    out vec4 stop3;
    out vec2 stop_dir;
    out float grad_type;

    void main() {
        gl_Position = mvp * vec4(position.xy, 0.0, 1.0);
        uv = texcoord0;
        color = color0;
        params = position.z;
        // Pass gradient stops to FS via varyings
        stop1 = tm[0];
        stop2 = tm[1];
        stop3 = tm[2];
        stop_dir = tm[3].xy;
        grad_type = tm[3].z;
    }
'

const fs_gradient_glsl = '
    #version 330
    uniform sampler2D tex;
    in vec2 uv;
    in vec4 color;
    in float params;
    in vec4 stop1;
    in vec4 stop2;
    in vec4 stop3;
    in vec2 stop_dir;
    in float grad_type;

    out vec4 frag_color;

    float random(vec2 coords) {
        return fract(sin(dot(coords.xy, vec2(12.9898,78.233))) * 43758.5453);
    }

    void main() {
        float radius = floor(params / 1000.0);

        // SDF clipping for rounded rect
        vec2 uv_to_px = 1.0 / (vec2(fwidth(uv.x), fwidth(uv.y)) + 1e-6);
        vec2 half_size = uv_to_px;
        vec2 pos = uv * half_size;

        vec2 q = abs(pos) - half_size + vec2(radius);
        float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;

        float grad_len = length(vec2(dFdx(d), dFdy(d)));
        d = d / max(grad_len, 0.001);
        float sdf_alpha = 1.0 - smoothstep(-0.59, 0.59, d);

        // Unified gradient t calculation
        float t;
        if (grad_type > 0.5) {
            // Radial: distance from center with aspect correction
            vec2 aspect = stop_dir;
            t = length(uv * aspect);
        } else {
            // Linear: project onto direction vector
            vec2 dir = stop_dir;
            t = dot(uv, dir) * 0.5 + 0.5;
        }
        t = clamp(t, 0.0, 1.0);

        // Multi-stop interpolation
        vec4 gradient_color;
        vec4 c1, c2;
        float local_t;

        if (t <= stop2.a) {
            c1 = stop1;
            c2 = stop2;
            local_t = (t - stop1.a) / max(stop2.a - stop1.a, 0.0001);
        } else {
            c1 = stop2;
            c2 = stop3;
            local_t = (t - stop2.a) / max(stop3.a - stop2.a, 0.0001);
        }

        // Premultiplied alpha interpolation (CSS spec)
        // Currently stops are packed as (r,g,b,position), alpha=1.0
        // Structure ready for alpha support when stop format extended
        float c1_alpha = 1.0;  // TODO: read from extended stop format
        float c2_alpha = 1.0;
        vec3 c1_pre = c1.rgb * c1_alpha;
        vec3 c2_pre = c2.rgb * c2_alpha;
        vec3 rgb_pre = mix(c1_pre, c2_pre, local_t);
        float alpha = mix(c1_alpha, c2_alpha, local_t);
        vec3 rgb = rgb_pre / max(alpha, 0.0001);
        gradient_color = vec4(rgb, alpha);

        // Add dithering to prevent color banding
        float dither = (random(gl_FragCoord.xy) - 0.5) / 255.0;
        gradient_color.rgb += vec3(dither);

        // Combine gradient with SDF clipping
        frag_color = vec4(gradient_color.rgb, gradient_color.a * sdf_alpha);

        // sgl workaround: dummy texture sample
        if (frag_color.a < 0.0) {
            frag_color += texture(tex, uv);
        }
    }
'
