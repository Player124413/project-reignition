shader_type spatial;
render_mode specular_disabled, blend_add;

global uniform float time;

uniform sampler2D albedo : hint_default_transparent;
uniform sampler2D displacement : hint_default_black;
uniform float time_scale : hint_range(0.0, 1.0, 0.1) = 0.2;
uniform float displacement_scale : hint_range(1.0, 5.0, 1.0) = 2.0;

void fragment() {
	vec4 displacement_sample = texture(displacement, (UV2 * displacement_scale) - vec2(0.0, time * time_scale));
	vec2 uv = UV + displacement_sample.xy;
	vec4 col = texture(albedo, uv + vec2(time * time_scale)) * COLOR;
	ALBEDO = col.rgb;
	ALPHA = col.a;
}
