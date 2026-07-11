shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

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
uniform bool use_prm = true;
uniform sampler2D prm_tex : hint_default_white;
uniform bool prm_roughness_invert = false;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.2;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform float ao_light_affect : hint_range(0.0, 1.0) = 0.0;

group_uniforms FakeGlass;
uniform float falloff_scale : hint_range(0.0, 2.0) = 0.85;
uniform float falloff_power : hint_range(0.1, 16.0) = 4.0;
uniform float falloff_bias : hint_range(-1.0, 1.0) = 0.05;
uniform float rim_strength : hint_range(0.0, 4.0) = 1.0;
uniform float base_alpha : hint_range(0.0, 1.0) = 0.3;
uniform bool fresnel_drives_alpha = true;
uniform sampler2D transparency_tex : source_color, hint_default_white;
uniform bool use_transparency_tex_alpha = false;

void fragment() {
    vec2 uv = UV * uv_scale + uv_offset;

    vec4 alb = texture(albedo_tex, uv);
    ALBEDO = alb.rgb * diffuse_color;

    vec3 nrm = texture(normal_tex, uv).rgb;
    if (normal_flip_y) nrm.g = 1.0 - nrm.g;
    NORMAL_MAP = nrm;
    NORMAL_MAP_DEPTH = normal_scale;

    if (use_prm) {
        vec4 prm = texture(prm_tex, uv);
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

    float ndotv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
    float fresnel = pow(clamp((1.0 - ndotv) + falloff_bias, 0.0, 1.0), falloff_power) * falloff_scale;

    RIM = clamp(fresnel * rim_strength, 0.0, 1.0);
    RIM_TINT = 0.0;

    float a = base_alpha;
    if (use_transparency_tex_alpha) a *= texture(transparency_tex, uv).a;
    if (fresnel_drives_alpha) {
        ALPHA = clamp(mix(a, 1.0, fresnel), 0.0, 1.0);
    } else {
        ALPHA = a;
    }
}
