shader_type spatial;
render_mode specular_disabled;

global uniform float time;

uniform sampler2D albedo : hint_default_transparent;
uniform sampler2D displacement : hint_default_black;
uniform float time_scale : hint_range(0.0, 1.0, 0.1) = 0.2;

void fragment() {
	vec2 uv_offset = texture(displacement, UV2 - vec2(0.0, time * time_scale)).rg;
	vec2 uv = UV + uv_offset;
	vec4 col = texture(albedo, uv + vec2(time * time_scale)) * COLOR;
	ALBEDO = col.rgb;
	ALPHA = col.a;
}
