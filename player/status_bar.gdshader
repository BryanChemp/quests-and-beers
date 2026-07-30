shader_type canvas_item;

uniform vec4 fill_color : source_color = vec4(0.85, 0.12, 0.10, 1.0);
uniform vec4 light_color : source_color = vec4(1.0, 0.35, 0.28, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.45, 0.04, 0.03, 1.0);

uniform float light_height : hint_range(0.0, 1.0) = 0.28;
uniform float shadow_height : hint_range(0.0, 1.0) = 0.72;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    if (tex.a <= 0.01) {
        discard;
    }

    vec3 color = fill_color.rgb;

    // Parte de cima iluminada
    if (UV.y < light_height) {
        color = light_color.rgb;
    }

    // Parte inferior escura
    if (UV.y > shadow_height) {
        color = shadow_color.rgb;
    }

    COLOR = vec4(color, tex.a);
}