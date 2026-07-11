shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
group_uniforms Layer0_UV;
uniform sampler2D albedo0_tex : source_color, hint_default_white;
uniform sampler2D normal0_tex : hint_normal;
uniform sampler2D prm0_tex : hint_default_white;
uniform vec2 uv0_scale  = vec2(1.0, 1.0);
uniform vec2 uv0_offset = vec2(0.0, 0.0);
group_uniforms Layer1_UV;
uniform sampler2D albedo1_tex : source_color, hint_default_white;
uniform sampler2D normal1_tex : hint_normal;
uniform sampler2D prm1_tex : hint_default_white;
uniform vec2 uv1_scale  = vec2(1.0, 1.0);
uniform vec2 uv1_offset = vec2(0.0, 0.0);
group_uniforms Blend;
uniform bool use_vertex_alpha_blend = true;
uniform float blend_constant : hint_range(0.0, 1.0) = 0.0;
uniform float blend_bias : hint_range(-1.0, 1.0) = 0.0;
uniform bool invert_blend = false;
uniform bool use_vertex_color_tint = true;
group_uniforms Appearance;
uniform vec3 diffuse_color : source_color = vec3(0.8, 0.8, 0.8);
uniform bool normal_flip_y = true;
uniform float normal_scale : hint_range(-2.0, 2.0) = 1.0;
group_uniforms PBR;
uniform bool use_prm = true;
uniform bool prm_roughness_invert = false;
uniform float ao_light_affect : hint_range(0.0, 1.0) = 0.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float specular : hint_range(0.0, 1.0) = 0.0;
void fragment() {
    vec2 uv0 = UV * uv0_scale + uv0_offset;
    vec2 uv1 = UV * uv1_scale + uv1_offset;

    vec3 a0 = texture(albedo0_tex, uv0).rgb * diffuse_color;
    if (use_vertex_color_tint) a0 *= COLOR.rgb;
    vec3 a1 = texture(albedo1_tex, uv1).rgb;

    float blend = use_vertex_alpha_blend ? COLOR.a : blend_constant;
    blend = clamp(blend + blend_bias, 0.0, 1.0);
    if (invert_blend) blend = 1.0 - blend;

    ALBEDO = mix(a0, a1, blend);

    vec3 n0 = texture(normal0_tex, uv0).rgb;
    vec3 n1 = texture(normal1_tex, uv1).rgb;
    if (normal_flip_y) { n0.g = 1.0 - n0.g; n1.g = 1.0 - n1.g; }
    NORMAL_MAP = mix(n0, n1, blend);
    NORMAL_MAP_DEPTH = normal_scale;

    if (use_prm) {
        vec4 prm0 = texture(prm0_tex, uv0);
        vec4 prm1 = texture(prm1_tex, uv1);
        vec4 prm = mix(prm0, prm1, blend);
        SPECULAR = prm.r;
        ROUGHNESS = prm_roughness_invert ? (1.0 - prm.g) : prm.g;
        METALLIC = prm.b;
        AO = prm.a;
        AO_LIGHT_AFFECT = ao_light_affect;
    } else {
        METALLIC = metallic;
        ROUGHNESS = roughness;
        SPECULAR = specular;
    }
}