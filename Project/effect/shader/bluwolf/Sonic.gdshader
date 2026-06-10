shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert;

uniform sampler2D diffuse_texture : source_color;
uniform sampler2D specular_texture;
uniform sampler2D normal_texture;
uniform sampler2D falloff_texture;

uniform sampler2D environment_texture_1;
uniform sampler2D environment_texture_2;
uniform sampler2D environment_texture_3;

uniform sampler2D environment_mask_1;
uniform sampler2D environment_mask_2;
uniform sampler2D environment_mask_3;

uniform sampler2D emission_texture : source_color;

uniform bool enable_normal_map;
uniform bool enable_environment_map;
uniform bool enable_alpha_scissor;
uniform bool enable_backface_culling = true;

uniform vec4 diffuse_color : source_color;
uniform vec4 specular_color : source_color;

uniform vec4 power_gloss_level;
uniform vec4 sonic_skin_falloff_param;
uniform float luminance_range;

uniform float normal_intensity : hint_range(0.0, 2.0, 0.01) = 1.0;

uniform float env_intensity_1 : hint_range(0.0, 8.0, 0.01) = 1.0;
uniform float env_intensity_2 : hint_range(0.0, 8.0, 0.01) = 1.0;
uniform float env_intensity_3 : hint_range(0.0, 8.0, 0.01) = 1.0;

uniform float emission_intensity : hint_range(0.0, 16.0, 0.01) = 0.0;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0, 0.001) = 0.5;

varying vec4 vColor;


// ── Helpers ─────────────────────────────────────────

vec3 decode_normal_map(vec4 n)
{
	n.x *= n.w;
	n.xy = n.xy * 2.0 - 1.0;
	n.z = sqrt(max(0.0, 1.0 - dot(n.xy, n.xy)));
	return n.xyz;
}

float compute_falloff(float cos_theta)
{
	return pow(clamp(1.0 - cos_theta, 0.0, 1.0), sonic_skin_falloff_param.z);
}

float compute_fresnel(float cos_theta)
{
	return pow(clamp(1.0 - cos_theta, 0.0, 1.0), 5.0) * 0.7 + 0.3;
}


// ── Vertex ─────────────────────────────────────────

void vertex()
{
	vColor = COLOR;
}


// ── Fragment ───────────────────────────────────────

void fragment()
{
	if (enable_backface_culling && !FRONT_FACING)
	{
		discard;
	}

	vec4 diffuse = texture(diffuse_texture, UV);

	ALBEDO = COLOR.rgb * diffuse.rgb * diffuse_color.rgb;

	ALPHA = diffuse.a * diffuse_color.a;
	ALPHA_SCISSOR_THRESHOLD = enable_alpha_scissor ? alpha_scissor_threshold : 0.0;

	if (enable_normal_map)
	{
		vec4 nmap = texture(normal_texture, UV);

		vec3 tangent_normal = decode_normal_map(nmap);

		// Normal map intensity control
		tangent_normal = normalize(
			mix(vec3(0.0, 0.0, 1.0), tangent_normal, normal_intensity)
		);

		NORMAL = normalize(
			tangent_normal.x * TANGENT +
			tangent_normal.y * BINORMAL +
			tangent_normal.z * NORMAL
		);
	}

	float specular_fresnel = compute_fresnel(dot(NORMAL, VIEW));

	if (enable_environment_map)
	{
		vec4 specular = texture(specular_texture, UV);
		vec3 vertex_color = COLOR.rgb;

		vec2 env_uv = NORMAL.xy * vec2(0.5, -0.5) + 0.5;

		// ENVIRONMENT 1
		vec4 env1 = texture(environment_texture_1, env_uv);
		float mask1 = texture(environment_mask_1, UV).r;

		env1.rgb += env1.rgb * env1.w * luminance_range;
		env1.rgb *= specular.w * specular_fresnel;
		env1.rgb *= vertex_color;
		env1.rgb *= mask1 * env_intensity_1;

		EMISSION += env1.rgb * env1.rgb;

		// ENVIRONMENT 2
		vec4 env2 = texture(environment_texture_2, env_uv);
		float mask2 = texture(environment_mask_2, UV).r;

		env2.rgb += env2.rgb * env2.w * luminance_range;
		env2.rgb *= specular.w * specular_fresnel;
		env2.rgb *= vertex_color;
		env2.rgb *= mask2 * env_intensity_2;

		EMISSION += env2.rgb * env2.rgb;

		// ENVIRONMENT 3
		vec4 env3 = texture(environment_texture_3, env_uv);
		float mask3 = texture(environment_mask_3, UV).r;

		env3.rgb += env3.rgb * env3.w * luminance_range;
		env3.rgb *= specular.w * specular_fresnel;
		env3.rgb *= vertex_color;
		env3.rgb *= mask3 * env_intensity_3;

		EMISSION += env3.rgb * env3.rgb;
	}

	vec3 emission_tex = texture(emission_texture, UV).rgb;
	EMISSION += emission_tex * emission_intensity;
}


// ── Light ──────────────────────────────────────────

void light()
{
	float nDotL = dot(LIGHT, NORMAL);
	nDotL = (nDotL - 0.05) / (1.0 - 0.05);
	nDotL = clamp(nDotL, 0.0, 1.0);
	nDotL *= nDotL;

	vec4 falloff_tex = texture(falloff_texture, UV);
	float falloff_fac = compute_falloff(dot(NORMAL, VIEW));

	vec3 rim_light = vColor.rgb * falloff_tex.rgb * falloff_fac;
	rim_light *= rim_light;
	rim_light *= LIGHT_COLOR / PI;

	DIFFUSE_LIGHT +=
		(nDotL * ALBEDO * LIGHT_COLOR * ATTENUATION) +
		(rim_light * ATTENUATION * LIGHT_COLOR * sonic_skin_falloff_param.x);

	float specular_fresnel = compute_fresnel(dot(NORMAL, VIEW));
	float specular_gloss = clamp(power_gloss_level.y * 500.0, 1.0, 1024.0);
	float specular_level = power_gloss_level.z * 5.0;

	vec4 specular_tex = texture(specular_texture, UV);

	vec3 halfway = normalize(LIGHT + VIEW);

	float spec_cos =
		pow(
			clamp(dot(halfway, NORMAL), 0.0, 1.0),
			specular_gloss
		);

	specular_tex.rgb *= spec_cos;
	specular_tex.rgb *= specular_level;
	specular_tex.rgb *= specular_fresnel;
	specular_tex.rgb *= specular_tex.rgb;

	SPECULAR_LIGHT +=
		specular_tex.rgb * LIGHT_COLOR * ATTENUATION * 100.0 * SPECULAR_AMOUNT;

	SPECULAR_LIGHT +=
		specular_tex.rgb * LIGHT_COLOR * ATTENUATION * 100.0 * SPECULAR_AMOUNT +
		(rim_light * ATTENUATION * LIGHT_COLOR * nDotL * sonic_skin_falloff_param.y);
}