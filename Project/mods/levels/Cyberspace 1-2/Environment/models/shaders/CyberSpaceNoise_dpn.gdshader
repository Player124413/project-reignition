shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

group_uniforms Rendering;
uniform bool double_sided = false;
uniform bool alpha_scissor_enabled = false;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

group_uniforms Albedo;
uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform vec3 diffuse_color : source_color = vec3(0.8, 0.8, 0.8);
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);

group_uniforms Normal;
uniform sampler2D normal_tex : hint_normal;
uniform float normal_scale : hint_range(-2.0, 2.0) = 1.0;
uniform bool normal_flip_y = true;

group_uniforms PBR;
uniform bool use_prm = true;
uniform sampler2D prm_tex : hint_default_white;
uniform bool prm_roughness_invert = false;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform float ao_light_affect : hint_range(0.0, 1.0) = 0.0;

group_uniforms Emission;
uniform sampler2D emission_tex : source_color, hint_default_black;
uniform vec3 emission_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float emission_energy = 0.0;

group_uniforms CyberSpaceNoise;
uniform bool overlay_enabled = false;
uniform sampler2D noise_tex : hint_default_black, filter_nearest, repeat_enable;
uniform int overlay_blend_mode : hint_range(0, 2) = 0;
uniform float overlay_strength : hint_range(0.0, 2.0) = 1.0;
uniform vec3 overlay_tint : source_color = vec3(1.0, 1.0, 1.0);
uniform vec2 overlay_scroll = vec2(0.0, 0.2);
uniform vec2 overlay_tiling = vec2(1.0, 8.0);
uniform bool overlay_use_screen_uv = true;

varying vec2 model_uv;

void vertex() {
    model_uv = UV;
}

void fragment() {
    // Emulate backface culling with a toggle.
    if (!FRONT_FACING && !double_sided) {
        discard;
    }

    vec2 uv = UV * uv_scale + uv_offset;

    vec4 alb = texture(albedo_tex, uv);

    // Optional alpha scissor.
    if (alpha_scissor_enabled && alb.a < alpha_scissor_threshold) {
        discard;
    }

    ALBEDO = alb.rgb * diffuse_color;

    if (overlay_enabled) {
        vec2 ouv = (overlay_use_screen_uv ? SCREEN_UV : model_uv)
            * (overlay_tiling * 1.5) + TIME * -overlay_scroll;

        float m = texture(noise_tex, fract(ouv)).r;
        vec3 ov = overlay_tint * m;

        if (overlay_blend_mode == 0) {
            ALBEDO = mix(ALBEDO, ALBEDO * ov, overlay_strength);
        } else if (overlay_blend_mode == 1) {
            ALBEDO += ov * overlay_strength;
        } else {
            ALBEDO = mix(ALBEDO, ov, overlay_strength * m);
        }
    }

    vec3 nrm = texture(normal_tex, uv).rgb;

    if (normal_flip_y) {
        nrm.g = 1.0 - nrm.g;
    }

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

    vec3 ems = texture(emission_tex, uv).rgb * emission_color;
    EMISSION = ems * emission_energy;
}