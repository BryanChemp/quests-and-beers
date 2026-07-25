shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);

uniform float shadow_strength : hint_range(0.0,1.0) = 0.35;
uniform float light_steps : hint_range(2.0,8.0) = 3.0;

uniform bool use_texture = false;
uniform sampler2D tex : source_color;

void fragment() {

    vec3 color = albedo.rgb;

    if(use_texture){
        color *= texture(tex, UV).rgb;
    }

    ALBEDO = color;
}

void light(){

    float ndotl = max(dot(NORMAL, LIGHT),0.0);

    // Quantização
    ndotl = floor(ndotl * light_steps) / light_steps;

    vec3 diffuse = ALBEDO * LIGHT_COLOR * ndotl;

    // sombra nunca fica totalmente preta
    diffuse = mix(ALBEDO * shadow_strength, diffuse, ndotl);

    DIFFUSE_LIGHT += diffuse * ATTENUATION;
}