shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert;

uniform sampler2D diffuse_texture : source_color;
uniform sampler2D specular_texture;
uniform sampler2D normal_texture;
uniform sampler2D falloff_texture;
uniform sampler2D environment_texture;
uniform sampler2D emission_texture : source_color;

uniform bool enable_normal_map;
uniform bool enable_environment_map;
uniform bool enable_alpha_scissor;                                          // NEW

uniform vec4 diffuse_color : source_color;
uniform vec4 specular_color : source_color;

uniform vec4 power_gloss_level;
uniform vec4 sonic_skin_falloff_param;
uniform float luminance_range;
uniform float emission_intensity : hint_range(0.0, 16.0, 0.01) = 0.0;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0, 0.001) = 0.5; // NEW

varying vec4 vColor;

// ── Helpers ──────────────────────────────────────────────────────────────────

vec3 decode_normal_map(vec4 n)
{
    n.x *= n.w;
    n.xy = n.xy * 2.0 - 1.0;
    n.z  = sqrt(1.0 - dot(n.xy, n.xy));
    return n.xyz;
}

float compute_falloff(float cos_theta)
{
    return pow(clamp(1.0 - cos_theta, 0.0, 1.0), sonic_skin_falloff_param.z)
           * sonic_skin_falloff_param.y
           + sonic_skin_falloff_param.x;
}

float compute_fresnel(float cos_theta)
{
    return pow(clamp(1.0 - cos_theta, 0.0, 1.0), 5.0) * 0.7 + 0.3;
}

// ── Vertex ───────────────────────────────────────────────────────────────────

void vertex()
{
    vColor      = COLOR;
}

// ── Fragment ─────────────────────────────────────────────────────────────────

void fragment()
{
    vec4 diffuse = texture(diffuse_texture, UV);

    ALBEDO = COLOR.rgb * diffuse.rgb * diffuse_color.rgb;

    // ALPHA SCISSOR ───────────────────────────────────────────────────────────
    ALPHA = diffuse.a * diffuse_color.a;
    ALPHA_SCISSOR_THRESHOLD = enable_alpha_scissor ? alpha_scissor_threshold : 0.0;
    // ─────────────────────────────────────────────────────────────────────────

    if (enable_normal_map)
    {
        vec4 nmap = texture(normal_texture, UV);
        nmap.xyz  = decode_normal_map(nmap);
        NORMAL    = normalize(nmap.x * TANGENT + nmap.y * BINORMAL + nmap.z * NORMAL);
    }

    float specular_fresnel = compute_fresnel(dot(NORMAL, VIEW));

    if (enable_environment_map)
    {
        vec4 specular       = texture(specular_texture, UV);
        vec4 env_map        = texture(environment_texture, NORMAL.xy * vec2(0.5, -0.5) + 0.5);
        env_map.rgb        += env_map.rgb * env_map.w * luminance_range;
        env_map.rgb        *= specular.w * specular_fresnel;
        EMISSION           += env_map.rgb * env_map.rgb;
    }

    vec3 emission_tex = texture(emission_texture, UV).rgb;
    EMISSION += emission_tex * emission_intensity;
}

// ── Light ────────────────────────────────────────────────────────────────────

void light()
{
    const float M_PI = 3.14159265;

    float nDotL = dot(LIGHT, NORMAL);
    nDotL       = (nDotL - 0.05) / (1.0 - 0.05);
    nDotL       = clamp(nDotL, 0.0, 1.0);
    nDotL      *= nDotL;

    vec4  falloff_tex = texture(falloff_texture, UV);
    float falloff_fac = compute_falloff(dot(NORMAL, VIEW));
    vec3  rim_light   = vColor.rgb * falloff_tex.rgb * falloff_fac;
    rim_light        *= rim_light;
    rim_light        *= LIGHT_COLOR / M_PI;

    DIFFUSE_LIGHT += (nDotL * ALBEDO * LIGHT_COLOR * ATTENUATION) + (rim_light * ATTENUATION);

    float specular_fresnel = compute_fresnel(dot(NORMAL, VIEW));
    float specular_gloss   = clamp(power_gloss_level.y * 500.0, 1.0, 1024.0);
    float specular_level   = power_gloss_level.z * 5.0;

    vec4  specular_tex    = texture(specular_texture, UV);
    vec3  halfway         = normalize(LIGHT + VIEW);
    float spec_cos        = pow(clamp(dot(halfway, NORMAL), 0.0, 1.0), specular_gloss);

    specular_tex.rgb *= spec_cos;
    specular_tex.rgb *= specular_level;
    specular_tex.rgb *= specular_fresnel;
    specular_tex.rgb *= specular_tex.rgb;

    SPECULAR_LIGHT += specular_tex.rgb * LIGHT_COLOR * ATTENUATION * 100.0;
}