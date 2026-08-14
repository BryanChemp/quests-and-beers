shader_type canvas_item;

uniform float pixel_size: hint_range(1.0, 20.0, 1.0) = 4.0;
uniform float levels: hint_range(2.0, 64.0, 1.0) = 16.0;
uniform vec2 gamma = vec2(1.0, 1.0);
uniform float dithering_strength: hint_range(0.0, 2.0, 0.01) = 0.6;
uniform float contrast: hint_range(1.0, 3.0, 0.01) = 1.1;
uniform float saturation: hint_range(0.0, 2.0, 0.01) = 1.15;
uniform float smoothness: hint_range(0.0, 1.0, 0.01) = 0.35;

float bayer4x4(vec2 position) {
    int x = int(mod(position.x, 4.0));
    int y = int(mod(position.y, 4.0));
    int[16] m = { 0, 8, 2,10,
                 12, 4,14, 6,
                  3,11, 1, 9,
                 15, 7,13, 5 };
    return float(m[y * 4 + x]) / 16.0;
}

void fragment() {
    vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
    vec2 pcount = tex_size / pixel_size;

    vec2 uv_scaled = UV * pcount;
    vec2 uv_floor  = floor(uv_scaled) + 0.5;
    vec2 uv_frac   = fract(uv_scaled);
    vec2 uv_smooth = uv_floor + smoothstep(0.5 - smoothness*0.5, 0.5 + smoothness*0.5, uv_frac) - 0.5;
    vec2 final_uv  = uv_smooth / pcount;

    vec4 color = texture(TEXTURE, final_uv);
    color.rgb = pow(color.rgb, vec3(gamma.x));

    vec3 q = color.rgb * levels;
    vec3 qf = floor(q) / levels;
    vec3 qc = ceil(q)  / levels;
    vec3 quantized = mix(qf, qc, step(0.5, fract(q)));

    if (dithering_strength > 0.0) {
        float d = (bayer4x4(floor(FRAGCOORD.xy)) - 0.5) * dithering_strength / levels;
        quantized += d;
    }

    color.rgb = clamp(quantized, 0.0, 1.0);
    color.rgb = (color.rgb - 0.5) * contrast + 0.5;
    float g = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    color.rgb = mix(vec3(g), color.rgb, saturation);
    color.rgb = pow(clamp(color.rgb, 0.0, 1.0), vec3(gamma.y));

    COLOR.rgb = color.rgb;
    COLOR.a = color.a;
}