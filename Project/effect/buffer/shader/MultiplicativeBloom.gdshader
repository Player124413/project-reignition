shader_type spatial;
render_mode blend_mul, unshaded, fog_disabled, depth_draw_never;

#define iResolution 1.0 / VIEWPORT_SIZE

uniform sampler2D bloom_texture : hint_default_white;
uniform sampler2D object_texture : hint_default_white;

uniform float strength : hint_range(0.0, 20.0, 0.1) = 1.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

vec3 blur(vec2 uv, vec2 s) {
	return 0.011194727 * texture(bloom_texture, uv - 10.000000000 * s).rgb +
		0.039368696 * texture(bloom_texture, uv - 8.415809477 * s).rgb +
		0.071308558 * texture(bloom_texture, uv - 6.435363708 * s).rgb +
		0.110237219 * texture(bloom_texture, uv - 4.455121108 * s).rgb +
		0.145451038 * texture(bloom_texture, uv - 2.475020813 * s).rgb +
		0.163798995 * texture(bloom_texture, uv - 0.495000167 * s).rgb +
		0.157439298 * texture(bloom_texture, uv + 1.485004498 * s).rgb +
		0.129158204 * texture(bloom_texture, uv + 3.465057055 * s).rgb +
		0.090434685 * texture(bloom_texture, uv + 5.445220765 * s).rgb +
		0.054043977 * texture(bloom_texture, uv + 7.425557483 * s).rgb +
		0.027564604 * texture(bloom_texture, uv + 9.406126897 * s).rgb;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 x_col = blur(uv, vec2(1.0) / iResolution.xy * strength);
	vec3 y_col = blur(uv, vec2(-1.0) / iResolution.xy * strength);
	vec3 col = min(x_col, y_col);
	
	// TODO Cut out objects based on depth buffer
	vec4 obj_col = texture(object_texture, uv);
	col += obj_col.a;
	col = clamp(col, vec3(0.0), vec3(1.0));
	ALBEDO = col;
}