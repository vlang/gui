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
        vec2 q_c = abs(pos - offset) - half_size + vec2(radius + 1.5 * blur);
        float d_c = length(max(q_c, 0.0)) + min(max(q_c.x, q_c.y), 0.0) - radius;

        // Shadow logic:
        // Clip inner shadow (d < 0) regarding casting box to prevent bleeding.
        float alpha_falloff = 1.0 - smoothstep(0.0, max(1.0, blur), d);
        float alpha_clip = smoothstep(-1.0, 0.0, d_c); // Hard fade at casting edge

        float alpha = alpha_falloff * alpha_clip;

        frag_color = vec4(color.rgb, color.a * alpha);

        if (frag_color.a < 0.0) {
            frag_color += texture(tex, uv);
        }
    }
'
