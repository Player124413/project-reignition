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
group_uniforms PRM;
uniform sampler2D prm_tex : hint_default_white;
uniform bool prm_roughness_invert = false;
uniform float metallic_scale : hint_range(0.0, 1.0) = 1.0;
uniform float roughness_scale : hint_range(0.0, 1.0) = 1.0;
uniform float specular_scale : hint_range(0.0, 1.0) = 1.0;
uniform float ao_light_affect : hint_range(0.0, 1.0) = 0.0;
group_uniforms Emission;
uniform sampler2D emission_tex : source_color, hint_default_black;
uniform vec3 emission_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float emission_energy = 0.0;
group_uniforms AlphaScissor;
uniform bool alpha_scissor_enabled = false;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    vec2 uv = UV * uv_scale + uv_offset;
    vec4 alb = texture(albedo_tex, uv);
    ALBEDO = alb.rgb * diffuse_color;

    if (alpha_scissor_enabled) {
        ALPHA = alb.a;
        ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
    }

    vec3 nrm = texture(normal_tex, uv).rgb;
    if (normal_flip_y) nrm.g = 1.0 - nrm.g;
    NORMAL_MAP = nrm;
    NORMAL_MAP_DEPTH = normal_scale;
    // Two-sided lighting: flip normal on back faces when culling is disabled.
    if (!FRONT_FACING) {
        NORMAL = -NORMAL;
    }

    vec4 prm = texture(prm_tex, uv);
    float rough = prm_roughness_invert ? (1.0 - prm.g) : prm.g;
    SPECULAR  = prm.r * specular_scale;
    ROUGHNESS = rough * roughness_scale;
    METALLIC  = prm.b * metallic_scale;
    AO = prm.a;
    AO_LIGHT_AFFECT = ao_light_affect;

    vec3 ems = texture(emission_tex, uv).rgb * emission_color;
    EMISSION = ems * emission_energy;
}