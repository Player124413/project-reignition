shader_type spatial;
render_mode unshaded, blend_add;

uniform sampler2D reflection_texture : hint_default_black, source_color;
instance uniform vec3 tint: source_color = vec3(1, 1, 1);

void fragment()
{
	vec2 uv = SCREEN_UV;
	uv.y *= -1.0;
	vec4 col = texture(reflection_texture, uv) * COLOR;
	ALBEDO = col.rgb * tint;
}
