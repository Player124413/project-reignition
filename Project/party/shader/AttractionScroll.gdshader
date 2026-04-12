shader_type spatial;
render_mode cull_disabled, specular_disabled, depth_prepass_alpha;

uniform sampler2D texture_albedo : source_color, repeat_disable, filter_linear;
instance uniform float ratio_shown : hint_range(0.0, 1.0, 0.1) = 0.0;

void fragment() {
	vec2 uv = UV - vec2(ratio_shown, 0.0);
	vec4 col = texture(texture_albedo, uv);
	col *= COLOR;
	
	ALBEDO = col.rgb;
	ALPHA *= col.a;
}
