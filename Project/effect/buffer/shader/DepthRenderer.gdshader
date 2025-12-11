shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled;

global uniform float render_distance;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment()
{
	float depth = texture(depth_texture, SCREEN_UV).x;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
	#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float linear_depth = -view.z;
	float normalized_depth = linear_depth / render_distance;
	
	ALBEDO = vec3(normalized_depth, linear_depth, depth);
	
	// Become transparent when nothing is found
	if(normalized_depth + (render_distance * (.99 / render_distance)) >= 1.0)
		ALPHA = 0.0;
	else
		ALPHA = 1.0;
}