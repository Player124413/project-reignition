shader_type spatial;
render_mode depth_draw_opaque, specular_disabled;

uniform sampler2D albedo : source_color;
uniform sampler2D detail : source_color;

void fragment() {
	vec4 albedo_col = texture(albedo, UV);
	vec4 text_col = texture(detail, UV);
	
	float textFade = clamp(smoothstep(1.5, 5.0, -VERTEX.z), 0.0, 1.0);
	ALBEDO = mix(albedo_col.rgb, text_col.rgb, textFade) * COLOR.rgb;
	ALPHA = albedo_col.a;
	ALPHA_SCISSOR_THRESHOLD = .1;
}
