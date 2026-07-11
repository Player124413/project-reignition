shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

group_uniforms Albedo;
uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform vec3 diffuse_color : source_color = vec3(0.8, 0.8, 0.8);
uniform vec2 uv_scale  = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);

group_uniforms Normal;
uniform sampler2D normal_tex : hint_normal;
uniform float normal_scale : hint_range(-2.0, 2.0) = 1.0;

uniform bool normal_flip_y = true;

group_uniforms PBR;

uniform float metallic : hint_range(0.0, 1.0) = 0.04;
uniform float roughness : hint_range(0.0, 1.0) = 0.21;

uniform float specular : hint_range(0.0, 1.0) = 0.5;

group_uniforms Emission;
uniform float emission_energy = 0.0;
uniform vec3  emission_color : source_color = vec3(0.0);

void fragment() {
    vec2 uv = UV * uv_scale + uv_offset;

    vec4 alb = texture(albedo_tex, uv);
    ALBEDO = alb.rgb * diffuse_color;

    vec3 n = texture(normal_tex, uv).rgb;
    if (normal_flip_y) n.g = 1.0 - n.g;
    NORMAL_MAP = n;
    NORMAL_MAP_DEPTH = normal_scale;

    METALLIC  = metallic;
    ROUGHNESS = roughness;
    SPECULAR  = specular;

    if (emission_energy > 0.0) EMISSION = emission_color * emission_energy;
}
