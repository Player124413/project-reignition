shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert;

uniform sampler2D diffuse_texture : source_color;
uniform sampler2D specular_texture;
uniform sampler2D falloff_texture;
uniform sampler2D environment_texture;
uniform sampler2D environment_mask_texture;
uniform sampler2D emission_texture : source_color;

uniform bool enable_environment_map;

uniform bool enable_alpha_scissor;

uniform vec4 diffuse_color : source_color;
uniform vec4 specular_color : source_color;

uniform vec4 power_gloss_level;
uniform vec4 sonic_skin_falloff_param;
uniform float luminance_range;
uniform float emission_intensity : hint_range(0.0, 16.0, 0.01) = 0.0;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0, 0.001) = 0.5;


uniform float CatchlightRadius           : hint_range(0.0, 1.0)   = 0.08;
uniform float CatchlightFeathering       : hint_range(0.0, 1.0)   = 0.04;
uniform vec3  CatchlightScale                                      = vec3(3.0, 2.0, 0.0);
uniform vec3  CatchlightOffset                                     = vec3(0.0, 0.0, 0.0);
uniform float XStrength                  : hint_range(0.0, 2.0)   = 1.0;
uniform float YStrength                  : hint_range(0.0, 2.0)   = 1.0;
uniform float CatchlightStrength         : hint_range(0.0, 4.0)   = 1.0;
uniform float CatchlightParallaxStrength : hint_range(0.0, 10.0)  = 1.0;
uniform vec3  CatchlightColor            : source_color            = vec3(1.0, 1.0, 1.0);


varying vec2 specular_uv;
varying vec4 vColor;

instance uniform vec2 uv_offset;


float compute_falloff(float cos_theta)
{
    return pow(clamp(1.0 - cos_theta, 0.0, 1.0), sonic_skin_falloff_param.z)
           * sonic_skin_falloff_param.y
           + sonic_skin_falloff_param.x;
}

float compute_fresnel(float cos_theta)
{
    return pow(clamp(1.0 - cos_theta, 0.0, 1.0), 5.0) * 0.7 + 0.3;
}


float compute_catchlight(vec2 uv, float camera_right_z, float camera_up_z)
{
   
    vec3 scaled = CatchlightScale * vec3(10.0, 10.0, 10.0);


    vec3 centre = vec3(0.5, 0.5, 0.0) * scaled + CatchlightOffset;


    vec3 pos = vec3(uv, 0.0) * scaled;

 
    vec3 cam_shift = vec3(camera_right_z * XStrength,
                          camera_up_z    * YStrength,
                          0.0) * CatchlightParallaxStrength;

  
    vec3 delta = (pos - centre) + cam_shift;

    float dist  = length(delta);
    float outer = CatchlightRadius + CatchlightFeathering;

  
    float mask  = 1.0 - smoothstep(CatchlightRadius, outer, dist);

    return mask * CatchlightStrength;
}


void vertex()
{
    UV          = UV2 + uv_offset;
    specular_uv = UV2;
    vColor      = COLOR;
}



void fragment()
{
    vec4 diffuse = texture(diffuse_texture, UV2);

    ALBEDO = COLOR.rgb * diffuse.rgb * diffuse_color.rgb;

   
    ALPHA = diffuse.a * diffuse_color.a;
    ALPHA_SCISSOR_THRESHOLD = enable_alpha_scissor ? alpha_scissor_threshold : 0.0;
 

    float specular_fresnel = compute_fresnel(dot(NORMAL, VIEW));

    if (enable_environment_map)
{
    vec4 specular    = texture(specular_texture, UV2);
    vec4 env_map     = texture(environment_texture, NORMAL.xy * vec2(0.5, -0.5) + 0.5);
    float env_mask   = texture(environment_mask_texture, UV2).r;   
    env_map.rgb     += env_map.rgb * env_map.w * luminance_range;
    env_map.rgb     *= specular.w * specular_fresnel;
    env_map.rgb     *= env_mask;                                    
    EMISSION        += env_map.rgb * env_map.rgb;
}

    vec3 emission_tex = texture(emission_texture, UV2).rgb;
    EMISSION += emission_tex * emission_intensity;


    float camera_right_z = INV_VIEW_MATRIX[0].z;
    float camera_up_z    = INV_VIEW_MATRIX[1].z;

    float catchlight_intensity = compute_catchlight(UV2, camera_right_z, camera_up_z);


    float eye_mask = texture(diffuse_texture, UV2).a;
    catchlight_intensity *= eye_mask;

    EMISSION += CatchlightColor * catchlight_intensity;
  
}


void light()
{
    const float M_PI = 3.14159265;

    float nDotL = dot(LIGHT, NORMAL);
    nDotL       = (nDotL - 0.05) / (1.0 - 0.05);
    nDotL       = clamp(nDotL, 0.0, 1.0);
    nDotL      *= nDotL;

    vec4  falloff_tex = texture(falloff_texture, specular_uv);
    float falloff_fac = compute_falloff(dot(NORMAL, VIEW));
    vec3  rim_light   = vColor.rgb * falloff_tex.rgb * falloff_fac;
    rim_light        *= rim_light;
    rim_light        *= LIGHT_COLOR / M_PI;

    DIFFUSE_LIGHT += (nDotL * ALBEDO * LIGHT_COLOR * ATTENUATION) + (rim_light * ATTENUATION);

    float specular_fresnel = compute_fresnel(dot(NORMAL, VIEW));
    float specular_gloss   = clamp(power_gloss_level.y * 500.0, 1.0, 1024.0);
    float specular_level   = power_gloss_level.z * 5.0;

    vec4  specular_tex = texture(specular_texture, specular_uv);
    vec3  halfway      = normalize(LIGHT + VIEW);
    float spec_cos     = pow(clamp(dot(halfway, NORMAL), 0.0, 1.0), specular_gloss);

    specular_tex.rgb *= spec_cos;
    specular_tex.rgb *= specular_level;
    specular_tex.rgb *= specular_fresnel;
    specular_tex.rgb *= specular_tex.rgb;

    SPECULAR_LIGHT += specular_tex.rgb * LIGHT_COLOR * ATTENUATION * 100.0;
}
