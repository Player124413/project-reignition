shader_type spatial;
render_mode blend_add, specular_disabled, unshaded, cull_disabled;

global uniform float time;

uniform sampler2D albedo : source_color, repeat_enable;
uniform sampler2D transparency_lut : source_color;
uniform int particles_anim_h_frames;
uniform int particles_anim_v_frames;
uniform bool particles_anim_loop;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 scroll_direction = vec2(0.0, 1.0);
uniform float time_scale = 1.0;

void vertex()
{
	UV2 = UV;
	
	UV *= uv_scale;
	float h_frames = float(particles_anim_h_frames);
	float v_frames = float(particles_anim_v_frames);
	float particle_total_frames = float(particles_anim_h_frames * particles_anim_v_frames);
	float particle_frame = floor(INSTANCE_CUSTOM.z * float(particle_total_frames));
	if (!particles_anim_loop)
	{
		particle_frame = clamp(particle_frame, 0.0, particle_total_frames - 1.0);
	}
	else
	{
		particle_frame = mod(particle_frame, particle_total_frames);
	}
	UV /= vec2(h_frames, v_frames);
	UV += vec2(mod(particle_frame, h_frames) / h_frames, floor((particle_frame + 0.5) / h_frames) / v_frames);
	UV += TIME * time_scale * scroll_direction;
}

void fragment()
{
	vec4 color = texture(albedo, UV);
	float transparency = texture(transparency_lut, vec2(UV2.g, 0.0)).r;
	color *= COLOR;
	ALBEDO = color.rgb;
	ALPHA *= color.a * transparency;
}
