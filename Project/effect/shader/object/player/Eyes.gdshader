shader_type spatial;
render_mode specular_disabled;

instance uniform vec2 uv_offset;

uniform sampler2D albedo : source_color;
uniform sampler2D emission_map : source_color;

uniform float emission_intensity : hint_range(0.0, 10.0, 0.01) = 1.0;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0, 0.01) = 0.5;

void vertex() {
	UV = UV + uv_offset;
}

void fragment() {
	vec4 col = texture(albedo, UV);
	col *= COLOR;

	ALBEDO = col.rgb;
	ALPHA *= col.a;

	/* Emission */
	vec3 emission_col = texture(emission_map, UV).rgb;
	emission_col *= COLOR.rgb;        // match albedo tinting
	EMISSION = emission_col * emission_intensity;

	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
}