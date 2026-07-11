shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

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
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float specular : hint_range(0.0, 1.0) = 0.3;
uniform float ao_light_affect : hint_range(0.0, 1.0) = 0.0;

group_uniforms AlphaTest;
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.25;

group_uniforms Wind;
uniform bool wind_enabled = true;
uniform vec2 wind_dir0 = vec2(1.0, 0.2);
uniform vec2 wind_dir1 = vec2(0.3, 1.0);
uniform float wind_phase_scale : hint_range(0.0, 2.0) = 0.25;

group_uniforms WindPrimary;
uniform float branch_amplitude : hint_range(0.0, 1.0) = 0.15;
uniform float branch_frequency : hint_range(0.0, 4.0) = 0.6;
uniform int branch_weight_channel : hint_range(0, 3) = 0;

group_uniforms WindSecondary;
uniform float leaf_amplitude : hint_range(0.0, 10.0) = 0.05;
uniform float leaf_frequency : hint_range(0.0, 12.0) = 3.0;
uniform int leaf_weight_channel : hint_range(0, 3) = 1;

float chan(vec4 c, int i) {
    if (i == 0) return c.r;
    if (i == 1) return c.g;
    if (i == 2) return c.b;
    return c.a;
}

vec3 two_wave(vec3 world, float freq, float t) {
    vec2 d0 = normalize(wind_dir0 + 1e-5);
    vec2 d1 = normalize(wind_dir1 + 1e-5);
    float p0 = dot(d0, world.xz) * wind_phase_scale + t;
    float p1 = dot(d1, world.xz) * wind_phase_scale + t * 1.3;
    float s0 = (sin(p0 * freq) + 1.0) * 0.5;
    float s1 = (sin(p1 * freq) + 1.0) * 0.5;
    return vec3(d0.x, 0.0, d0.y) * s0 + vec3(d1.x, 0.0, d1.y) * s1;
}

void vertex() {
    if (wind_enabled) {
        vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
        float wbranch = chan(COLOR, branch_weight_channel);
        float wleaf = chan(COLOR, leaf_weight_channel);
        vec3 branch = two_wave(world, branch_frequency, TIME) * branch_amplitude * wbranch;
        vec3 leaf = two_wave(world + VERTEX, leaf_frequency, TIME) * leaf_amplitude * wleaf;
        VERTEX += branch + leaf;
    }
}

void fragment() {
    vec2 uv = UV * uv_scale + uv_offset;

    vec4 alb = texture(albedo_tex, uv);
    ALBEDO = alb.rgb * diffuse_color;
    ALPHA = alb.a;
    ALPHA_SCISSOR_THRESHOLD = alpha_threshold;

    vec3 nrm = texture(normal_tex, uv).rgb;
    if (normal_flip_y) nrm.g = 1.0 - nrm.g;
    NORMAL_MAP = nrm;
    NORMAL_MAP_DEPTH = normal_scale;
    if (!FRONT_FACING) NORMAL = -NORMAL;

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
}
