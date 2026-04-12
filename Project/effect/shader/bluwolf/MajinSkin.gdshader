shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert;

uniform sampler2D diffuse_texture : source_color;
uniform sampler2D specular_texture;
uniform sampler2D normal_texture : hint_normal;
uniform sampler2D falloff_texture;
uniform sampler2D environment_texture;
uniform sampler2D environment_mask_texture : hint_default_black;
uniform sampler2D detail_environment_texture : hint_default_black;
uniform sampler2D detail_environment_mask_texture : hint_default_black;
uniform sampler2D emission_texture : source_color;
uniform sampler2D detail_emission_texture : hint_default_black, source_color;
uniform sampler2D detail_texture : hint_default_transparent, source_color;
uniform sampler2D detail_specular_texture : hint_default_black;

uniform bool enable_normal_map;
uniform bool enable_environment_map;
uniform bool enable_detail_environment_map;
uniform bool enable_alpha_scissor;
uniform bool enable_detail_map;
uniform bool enable_backface_cull = true;
uniform bool falloff_use_uv2;

uniform vec4 diffuse_color : source_color;
uniform vec4 specular_color : source_color;

uniform vec4 power_gloss_level;
uniform vec4 sonic_skin_falloff_param;
uniform float luminance_range;
uniform float luminance_range_uv2;
uniform float normal_intensity : hint_range(0.0, 4.0, 0.01) = 1.0;
uniform float emission_intensity : hint_range(0.0, 16.0, 0.01) = 0.0;
uniform float detail_emission_intensity : hint_range(0.0, 16.0, 0.01) = 0.0;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0, 0.001) = 0.5;
uniform float detail_blend_amount : hint_range(0.0, 1.0, 0.01) = 1.0;

varying vec4 vColor;

// ── Helpers ──────────────────────────────────────────────────────────────────

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
    if (enable_backface_cull && !FRONT_FACING) discard;

    vec4 diffuse = texture(diffuse_texture, UV);

    // UV2 DETAIL LAYER ────────────────────────────────────────────────────────
    vec4  detail_col      = vec4(0.0);
    vec4  detail_spec_col = vec4(0.0);
    float detail_alpha    = 0.0;

    if (enable_detail_map)
    {
        detail_col      = texture(detail_texture,          UV2);
        detail_spec_col = texture(detail_specular_texture, UV2);
        detail_alpha    = detail_col.a * detail_blend_amount;

        diffuse.rgb = mix(diffuse.rgb, detail_col.rgb, detail_alpha);
    }
    // ─────────────────────────────────────────────────────────────────────────

    ALBEDO = COLOR.rgb * diffuse.rgb * diffuse_color.rgb;

    // ALPHA SCISSOR ───────────────────────────────────────────────────────────
    ALPHA = diffuse.a * diffuse_color.a;
    ALPHA_SCISSOR_THRESHOLD = enable_alpha_scissor ? alpha_scissor_threshold : 0.0;
    // ─────────────────────────────────────────────────────────────────────────

    // NORMAL MAP ──────────────────────────────────────────────────────────────
    // Decodes a standard RGB normal map (R=X, G=Y, B=Z) and writes directly to
    // NORMAL so that every downstream use — fresnel, env map lookup, and the
    // entire light() function — all see the correct perturbed normal.
    // Scaling XY by normal_intensity before normalising controls depth:
    //   0.0 = flat, 1.0 = full strength, >1.0 = exaggerated.
    if (enable_normal_map)
    {
        vec4 n_tex = texture(normal_texture, UV);
        vec3 n;
        n.xy    = n_tex.xy * 2.0 - 1.0;
        n.z     = sqrt(max(1.0 - dot(n.xy, n.xy), 0.0));
        n.xy   *= normal_intensity;
        n       = normalize(n);
        NORMAL  = normalize(n.x * TANGENT + n.y * BINORMAL + n.z * NORMAL);
    }
    // ─────────────────────────────────────────────────────────────────────────

    float specular_fresnel = compute_fresnel(dot(NORMAL, VIEW));

    if (enable_environment_map)
    {
        vec4 specular = texture(specular_texture, UV);
        if (enable_detail_map)
            specular = mix(specular, detail_spec_col, detail_alpha);

        vec4 env_map      = texture(environment_texture, NORMAL.xy * vec2(0.5, -0.5) + 0.5);
        float env_mask    = texture(environment_mask_texture, UV).r;
        env_map.rgb      += env_map.rgb * env_map.w * luminance_range;
        env_map.rgb      *= specular.w * specular_fresnel * env_mask;
        EMISSION         += env_map.rgb * env_map.rgb;
    }

    // UV2 DETAIL ENVIRONMENT MAP ──────────────────────────────────────────────
    if (enable_detail_environment_map)
    {
        vec4  detail_env      = texture(detail_environment_texture, NORMAL.xy * vec2(0.5, -0.5) + 0.5);
        float detail_env_mask = texture(detail_environment_mask_texture, UV2).r;
        detail_env.rgb       += detail_env.rgb * detail_env.w * luminance_range_uv2;
        detail_env.rgb       *= specular_fresnel * detail_env_mask;
        EMISSION             += detail_env.rgb * detail_env.rgb;
    }
    // ─────────────────────────────────────────────────────────────────────────

    // EMISSION ────────────────────────────────────────────────────────────────
    EMISSION += texture(emission_texture, UV).rgb * emission_intensity * (1.0 - detail_alpha);
    vec4 detail_emission = texture(detail_emission_texture, UV2);
    EMISSION += detail_emission.rgb * detail_emission.a * detail_emission_intensity;
    // ─────────────────────────────────────────────────────────────────────────
}

// ── Light ────────────────────────────────────────────────────────────────────

void light()
{
    float nDotL = dot(LIGHT, NORMAL);
    nDotL       = (nDotL - 0.05) / (1.0 - 0.05);
    nDotL       = clamp(nDotL, 0.0, 1.0);
    nDotL      *= nDotL;

    // FALLOFF ─────────────────────────────────────────────────────────────────
    vec2 falloff_uv  = falloff_use_uv2 ? UV2 : UV;
    vec4 falloff_tex = texture(falloff_texture, falloff_uv);
    // ─────────────────────────────────────────────────────────────────────────

    float falloff_fac = compute_falloff(dot(NORMAL, VIEW));
    vec3  rim_light   = vColor.rgb * falloff_tex.rgb * falloff_fac;
    rim_light        *= rim_light;
    rim_light        *= LIGHT_COLOR / PI;

    DIFFUSE_LIGHT += (nDotL * ALBEDO * LIGHT_COLOR * ATTENUATION) + (rim_light * ATTENUATION);

	/*
    vec4 specular_tex = texture(specular_texture, UV);
    if (enable_detail_map)
    {
        vec4  d_col   = texture(detail_texture,          UV2);
        vec4  d_spec  = texture(detail_specular_texture, UV2);
        float d_alpha = d_col.a * detail_blend_amount;
        specular_tex  = mix(specular_tex, d_spec, d_alpha);
    }

    float specular_fresnel = compute_fresnel(dot(NORMAL, VIEW));
	float specular_gloss = clamp(power_gloss_level.y * 500.0, 1.0, 1024.0);
	float specular_level = power_gloss_level.z * 5.0;

	vec3  halfway  = normalize(LIGHT + VIEW);
	float spec_cos = pow(clamp(dot(halfway, NORMAL), 0.0, 1.0), specular_gloss);

	specular_tex.rgb *= spec_cos;
	specular_tex.rgb *= specular_level;
	specular_tex.rgb *= specular_fresnel;
	specular_tex.rgb *= specular_tex.rgb;
	
	Commented out because this causes odd rendering on some devices
	// SPECULAR_LIGHT += specular_tex.rgb * LIGHT_COLOR * ATTENUATION * 100.0 * SPECULAR_AMOUNT;
	*/
}
